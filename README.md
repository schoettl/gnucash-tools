GnuCash tools
=============

This is a collection of tools to work with GnuCash.

Create invoices in GnuCash using an article database
----------------------------------------------------

Filling in the entry lines for an invoice in GnuCash is a lot of typing.
Actually this data should come from an article database.

My solution searches for an article in a CSV file (the article database) and automatically fills in description, quantity, price, tax information, and more.

It's a Bash script which can be started with a launcher (e.g. Albert) or Alt-F2.
It uses `xdotool` which is available for Linux and Mac OS.

Usage:

1. Open a new invoice in GnuCash and place the cursor in the description column of the entry table.
2. Fire the execute dialog by pressing Alt-F2 (on most desktops).
3. Type `fie -n3 nuts`.
4. See how the tool fills in the entry line.

If there are multiple items matching "nuts" in the article database, you will be asked to select one.
The option `-n3` is optional and means "fill in a quantity of 3".


Create PDF tenders or invoices from GnuCash
-------------------------------------------

Another tool I've written automatically creates PDF tenders or invoices from invoices in GnuCash and store them in the appropriate folder.
It's not released yet because it's kind of ugly and uses SQLite, Python (csv2json), Ruby (mustache), Haskell (for calculation), Bash script, and LaTeX.
If you're still interested please drop me an e-mail.

Update GnuCash's customer table with data from EspoCRM
------------------------------------------------------

If you use EspoCRM and GnuCash with the same MySQL instance, you can periodically update GnuCash's customer data with data from EspoCRM.

- Customer (=account) data is only managed in the CRM.
- The GnuCash database gets automatically updated.

The link between the customers in GnuCash and EspoCRM is a line in EspoCRM's account description field:

```
Kundennummer: <customer id from GnuCash>
```

Bill an invoice and use HBCI online banking
-------------------------------------------

That's a real problem. It's not sensibly possible to use GnuCash with both invoices and online banking :(

Discussions:

- https://lists.gnucash.org/pipermail/gnucash-de/2005-October/003475.html
- https://lists.gnucash.org/pipermail/gnucash-de/2005-November/003604.html
- https://lists.gnucash.org/pipermail/gnucash-de/2005-November/003600.html

Looking at the invoice table in MySQL (`desc invoices;`), it seems that GnuCash
determines the "billed" state by looking into the `post_txn`, `post_lot`,
`post_acc` fields.

Where
- txn probably stands for tax
- lot = the bank account?
- acc = "Verbindlichkeiten", "Forderungen"

Would it work to set those fields with a script?

```
update invoices set
  post_txn = <guid_of_the_tax_account>,
  post_lot = <guid_of_the_lot_account>,
  post_acc = <guid_of_the_tax_account>
  where id = <invoice_id> and owner_type = <owner_type_lieferant_or_kunde>;
```

```
select b.name, owner_type, billto_type, billto_guid, c.name txn, d.name lot, e.name acc from invoices
  left join (
        select guid, name from customers
        union
        select guid, name from vendors
    ) as b on owner_guid = b.guid
  left join accounts c on post_txn = c.guid
  left join accounts d on post_lot = d.guid
  left join accounts e on post_acc = e.guid;
```
