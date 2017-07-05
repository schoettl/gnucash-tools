-- Update contacts in Fakturama2's contacts and address tables with data from EspoCRM's account table.
-- Address name and address lines of billing and shipping addresses are updated.

-- This script must be applied once, e.g. in Vim with :!mysql -uroot < %
-- A cron job should call the created procedure periodically, e.g.
-- echo "call gnucash.update_contacts_from_espo();" | /usr/bin/mysql -u espo_fakturama_sync fakturama

-- Create user with minimal permissions:
-- grant execute on procedure fakturama.update_contacts_from_espo to espo_fakturama_sync@localhost;


use fakturama;

-- For testing:
set @contact_id = 1;
set @addr_name = 'Jakob Schöttl';
set @addr_street = 'Im Kirchwinkel 17';
set @addr_zip = '83624';
set @addr_city = 'Otterfing';
set @addr_country = 'Deutschland';

set @espo_account_id = '58ad4efe04ae50c46';
set @contact_type = 'Debitor'; -- Debitor (or Creditor?)
set @id_number = '000037';

delimiter $$

drop procedure if exists set_address_for_contact;
create procedure set_address_for_contact(
  in contact_id bigint,
  in addr_name varchar(255),
  in addr_street varchar(255),
  in addr_zip varchar(255),
  in addr_city varchar(255),
  in addr_state varchar(255),
  in addr_country varchar(255))
begin
  select fk_address into @address_id from FKT_CONTACT where id = @contact_id;
  if @address_id is null then
    insert into FKT_ADDRESS () values ();
    set @address_id = last_insert_id();
    update FKT_CONTACT set fk_address = @address_id where id = @contact_id;
  end if;
  update FKT_ADDRESS set
    name        = @addr_name,
    street      = @addr_street,
    zip         = @addr_zip,
    city        = @addr_city,
    -- missing: state
    countrycode = @addr_country
    where id = @address_id;
end

$$

drop procedure if exists set_information_for_contact;
create procedure set_information_for_contact(
  in contact_id bigint,
  in company_name varchar(255))
begin
  update FKT_CONTACT set
    company = company_name
    where id = contact_id;
end

$$

drop procedure if exists update_contact;
create procedure update_contact(
  in espo_account_id varchar(24),
  in contact_type varchar(31), -- Debitor (or Creditor?)
  in id_number varchar(255))
begin

  if @contact_type = 'Debitor' then
    select id into @contact_id from FKT_CONTACT
      where dtype = 'Debitor' and customernumber = @id_number;
  else
    select 'error: only Debitor (customer is supported)';
    select id into @contact_id from FKT_CONTACT
      where dtype = 'XXX' and suppliernumber = @id_number;
    -- return;
  end if;

  select
    name,
    billing_address_street,
    billing_address_postal_code,
    billing_address_city,
    billing_address_state,
    billing_address_country,
    shipping_address_street,
    shipping_address_postal_code,
    shipping_address_city,
    shipping_address_state,
    shipping_address_country
  into
    @company_name,
    @ba_street,
    @ba_zip,
    @ba_city,
    @ba_state,
    @ba_country,
    @sa_street,
    @sa_zip,
    @sa_city,
    @sa_state,
    @sa_country
  from espocrm.account
  where id = @espo_account_id;

  -- Set billing address
  call set_information_for_contact(@contact_id, @company_name);
  call set_address_for_contact(@contact_id, @company_name, @ba_street, @ba_zip, @ba_city, @ba_state, @ba_country);

  select fk_alternatecontact into @shipping_contact_id
    from FKT_CONTACT where id = @contact_id;
  -- this construct should work for '' and NULL values:
  if @shipping_contact_id is null and (
     @sa_street  <> '' or
     @sa_zip     <> '' or
     @sa_city    <> '' or
     @sa_street  <> '' or
     @sa_country <> '') then
    insert into FKT_CONTACT () values ();
    set @shipping_contact_id = last_insert_id();
    update FKT_CONTACT set fk_alternatecontact = @shipping_contact_id where id = @contact_id;
  end if;

  -- Set shipping address if given
  if @shipping_contact_id is not null then
    call set_information_for_contact(@shipping_contact_id, @company_name);
    call set_address_for_contact(@shipping_contact_id, @company_name, @sa_street, @sa_zip, @sa_city, @sa_state, @sa_country);
  end if;

end

$$

drop procedure if exists update_contacts_from_espo;
create procedure update_contacts_from_espo()
begin
  set session sql_safe_updates = 0;

  set @keyword = 'Kundennummer:';
  set @likeKeyword = concat('%', @keyword, '%');
  set @customerIdLength = 7;
  set @accountType = 'Customer';

  drop temporary table if exists accounts_with_customer_id;
  create temporary table accounts_with_customer_id as
    select
      id as espo_account_id,
      name as espo_account_name,
      trim(substr(description, locate(@keyword, description) + length(@keyword), @customerIdLength)) as contact_id
    from espocrm.account
    where description like @likeKeyword;

  drop temporary table if exists temp_messages;
  create temporary table temp_messages (message_type varchar(10), message text);

  insert into temp_messages
    select
      'warning' as type,
      concat('Reference and account type of EspoCRM account do not match: ',
        name, ' (', id, ')') as message
    from espocrm.account
    where type <> @accountType and description like @likeKeyword;

  -- customers with references from more than 1 account -> error
  insert into temp_messages
    select
        'error' as type,
        concat(
          count(*), ' EspoCRM accounts refer to the same Fakturama contact ',
          contact_id, ': ',
          group_concat(espo_account_name separator ', '),
          ' (', group_concat(espo_account_id separator ', '), ')'
        ) as message
      from accounts_with_customer_id group by contact_id having count(*) > 1;

  -- accounts without customer id -> info
  insert into temp_messages
    select
        'info' as type,
        concat('EspoCRM account has no reference to a Fakturama contact: ',
          name, ' (', id, ')') as message
      from espocrm.account where description not like @likeKeyword;

  -- invalid customer id in EspoCRM accounts
  insert into temp_messages
    select
      'error' as type,
      concat('EspoCRM account has invalid reference to Fakturama contact: ',
        espo_account_name, ' (', espo_account_id, ')', ' -> ', contact_id) as message
      from
        (select espo_account_name, espo_account_id, contact_id from accounts_with_customer_id left join customers on contact_id = id collate utf8_general_ci where id is null) as a;

  select * from temp_messages;

  declare espo_account_id varchar(24);
  declare contact_id bigint;

  declare done int default false;
  declare cur cursor for select espo_account_id, contact_id from accounts_with_customer_id;
  declare continue handler for not found set done = true;
  open cur;
  loop1: loop
    fetch cur into espo_account_id, contact_id;
    if done then
      leave loop1;
    end if;
    call update_contact(espo_account_id, 'Debitor', contact_id)
  end loop;
  close cur;

--  update customers a
--    join accounts_with_customer_id t            on a.id = t.contact_id collate utf8_general_ci
--    join espocrm.account b on b.id = t.espo_account_id     collate utf8_general_ci
--    set
--      a.addr_name  = b.name,
--      a.addr_addr1 = b.billing_address_street,
--      a.addr_addr2 = concat(b.billing_address_postal_code, ' ', b.billing_address_city),
--      a.addr_addr3 = b.billing_address_state,
--      a.addr_addr4 = b.billing_address_country,
--      a.shipaddr_name  = b.name,
--      a.shipaddr_addr1 = b.shipping_address_street,
--      a.shipaddr_addr2 = concat(b.shipping_address_postal_code, ' ', b.shipping_address_city),
--      a.shipaddr_addr3 = b.shipping_address_state,
--      a.shipaddr_addr4 = b.shipping_address_country;

end

$$

delimiter ;


delimiter $$
drop procedure if exists test_proc;
create procedure test_proc()
begin

  declare espo_account_id varchar(24);
  declare contact_id bigint(20);

  declare a bigint;
  declare done int default false;
  declare cur cursor for select id from FKT_CONTACT;
  declare continue handler for not found set done = true;
  open cur;
  loop1: loop
    fetch cur into a;
    if done then
      leave loop1;
    end if;
  end loop;
  close cur;
end

$$

delimiter ;
