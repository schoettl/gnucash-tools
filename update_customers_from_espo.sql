-- Update customers in GnuCash's customers table with data from EspoCRM's account table.
-- Address name and address lines of billing and shipping addresses are updated.

-- This script must be applied once, e.g. in Vim with :!mysql -uroot < %
-- A cron job should call the created procedure periodically, e.g.
-- echo "call update_customers_from_espo_crm();" | mysql -u syncuser gnucash_db

use gnucash;

-- TODO make union of error and info messages? (the 2 select statements in the middle)

drop procedure update_customers_from_espo_crm;

delimiter $$
create procedure update_customers_from_espo_crm()
begin
  set @keyword = 'Kundennummer:';
  set @likeKeyword = concat('%', @keyword, '%');

  create temporary table temp as
    select
      id as espo_account_id,
      trim(substr(description, locate(@keyword, description) + length(@keyword), 7)) as gnucash_customer_id
    from espocrm.account
    where description like @likeKeyword;

  -- customers with references from more than 1 account -> error
  -- (how to get the account ids?)
  select gnucash_customer_id, count(*) as number, group_concat(espo_account_id separator ', ') as accounts from temp group by gnucash_customer_id having number > 1;
  -- accounts without customer id -> info
  select id, name from espocrm.account where description not like @likeKeyword;

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
