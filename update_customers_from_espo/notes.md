Discussion
==========

#### Why sync at all?

Because letters (invoices, offers, order confirmations, ...) are generated with data from GnuCash.
But I also use EspoCRM as a customer and contact database.

#### Why not generate letters from EspoCRM?

Because I use GnuCash for accounting which includes invoices.
Invoice ID and customer ID are generated in GnuCash.
The tool to generate letters should work with *one* database to keep it simple.

#### Why not sync bidirectional

KISS and I think it's better to stick to one application to maintain customer data.

#### Why not sync from GnuCash to EspoCRM?

Because EspoCRM is a better tool for managing customers.

#### Why not use the EspoCRM account ID as customer ID?

Because it's an ugly, long GUID.

#### Why not link EspoCRM account from GnuCash customer?

1. Because there is no free field in GnuCash customer.
2. Because the reference would by an ugly long GUID instead of the customer ID.

#### Why use the description field of the EspoCRM account?

Because it's the only available place.
