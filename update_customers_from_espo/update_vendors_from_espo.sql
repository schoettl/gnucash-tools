-- Update vendors in GnuCash's vendors table with data from EspoCRM's account table.
-- Address name and address lines of billing addresses are updated.

-- This script must be applied once, e.g. in Vim with :!mysql -uroot < %
-- A cron job should call the created procedure periodically, e.g.
-- echo "call gnucash.update_vendors_from_espocrm();" | /usr/bin/mysql -u espo_gc_sync gnucash_db


-- Create user with minimal permissions:
-- grant execute on procedure gnucash.update_vendors_from_espocrm to espo_gc_sync@localhost;


use gnucash;

drop procedure update_vendors_from_espocrm;

delimiter $$
create procedure update_vendors_from_espocrm()
begin
  set session sql_safe_updates = 0;

  set @keyword = 'Lieferantennummer:';
  set @likeKeyword = concat('%', @keyword, '%');
  set @vendorIdLength = 7;
  set @accountType = 'Partner';

  create temporary table temp as
    select
      id as espo_account_id,
      name as espo_account_name,
      trim(substr(description, locate(@keyword, description) + length(@keyword), @vendorIdLength)) as gnucash_vendor_id
    from espocrm.account
    where description like @likeKeyword;

  -- vendors with references from more than 1 account -> error
  create temporary table temp_messages (message_type varchar(10), message text);

  insert into temp_messages
    select
      'warning' as type,
      concat('Reference and account type of EspoCRM account do not match: ',
        name, ' (', id, ')') as message
    from espocrm.account
    where type <> @accountType and description like @likeKeyword;

  insert into temp_messages
    select
        'error' as type,
        concat(
          count(*), ' EspoCRM accounts refer to the same GnuCash vendor ',
          gnucash_vendor_id, ': ',
          group_concat(espo_account_name separator ', '),
          ' (', group_concat(espo_account_id separator ', '), ')'
        ) as message
      from temp group by gnucash_vendor_id having count(*) > 1;

  -- accounts without vendor id -> info
  insert into temp_messages
    select
        'info' as type,
        concat('EspoCRM account has no reference to a GnuCash vendor: ',
          name, ' (', id, ')') as message
      from espocrm.account where description not like @likeKeyword;

  -- invalid vendor id in EspoCRM accounts
  insert into temp_messages
    select
      'error' as type,
      concat('EspoCRM account has invalid reference to GnuCash vendor: ',
        espo_account_name, ' (', espo_account_id, ')', ' -> ', gnucash_vendor_id) as message
      from
        (select espo_account_name, espo_account_id, gnucash_vendor_id from temp left join vendors on gnucash_vendor_id = id collate utf8_general_ci where id is null) as a;

  select * from temp_messages;

  update vendors a
    left join temp t            on a.id = t.gnucash_vendor_id collate utf8_general_ci
    left join espocrm.account b on b.id = t.espo_account_id     collate utf8_general_ci
    set
      a.addr_name  = b.name,
      a.addr_addr1 = b.billing_address_street,
      a.addr_addr2 = concat(b.billing_address_postal_code, ' ', b.billing_address_city),
      a.addr_addr3 = b.billing_address_state,
      a.addr_addr4 = b.billing_address_country;

end$$
delimiter ;
