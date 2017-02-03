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
