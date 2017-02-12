-- Update customers in GnuCash's customers table with data from EspoCRM's account table.
-- Address name and address lines of billing and shipping addresses are updated.

-- This script must be applied once, e.g. in Vim with :!mysql -uroot < %
-- A cron job should call the created procedure periodically, e.g.
-- echo "call gnucash.update_customers_from_espocrm();" | /usr/bin/mysql -u espo_gc_sync gnucash_db


-- Create user with minimal permissions:
-- grant execute on procedure gnucash.update_customers_from_espocrm to espo_gc_sync@localhost;


use gnucash;

drop procedure update_customers_from_espocrm;

delimiter $$
create procedure update_customers_from_espocrm()
begin
  set @keyword = 'Kundennummer:';
  set @likeKeyword = concat('%', @keyword, '%');

  create temporary table temp as
    select
      id as espo_account_id,
      name as espo_account_name,
      trim(substr(description, locate(@keyword, description) + length(@keyword), 7)) as gnucash_customer_id
    from espocrm.account
    where description like @likeKeyword;

  select -- customers with references from more than 1 account -> error
      'error' as type,
      concat(
        count(*), ' EspoCRM accounts refer to the same GnuCash customer ',
        gnucash_customer_id, ': ',
        group_concat(espo_account_name separator ', '),
        ' (', group_concat(espo_account_id separator ', '), ')'
      ) as message
    from temp group by gnucash_customer_id having count(*) > 1
  union
  select -- accounts without customer id -> info
      'info' as type,
      concat('EspoCRM account has no reference to a GnuCash customer: ',
        name, ' (', id, ')') as message
    from espocrm.account where description not like @likeKeyword;

  update customers a
    left join temp t            on a.id = t.gnucash_customer_id collate utf8_general_ci
    left join espocrm.account b on b.id = t.espo_account_id     collate utf8_general_ci
    set
      a.addr_name  = b.name,
      a.addr_addr1 = b.billing_address_street,
      a.addr_addr2 = concat(b.billing_address_postal_code, ' ', b.billing_address_city),
      a.addr_addr3 = b.billing_address_state,
      a.addr_addr4 = b.billing_address_country,
      a.shipaddr_name  = b.name,
      a.shipaddr_addr1 = b.shipping_address_street,
      a.shipaddr_addr2 = concat(b.shipping_address_postal_code, ' ', b.shipping_address_city),
      a.shipaddr_addr3 = b.shipping_address_state,
      a.shipaddr_addr4 = b.shipping_address_country;

end$$
delimiter ;