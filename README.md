# AWS - snapBackup - Snapshot Based Backup for EC2

This script is foundamentally made to take attached EBS volumes of your EC2
Instance and make some snapshots **automagically**.

You can specify the _maximum amount of snapshots_ you want to retain for
a particoular EBS Volume with option __-x__, if _at the end_ of the process
there would be more than the specificied value, the script tries to delete the
oldest one.. if resulting amount is still higher than threshold it continues
to delete the oldest snapshot till the desired quantity is reached.

**__BEWARE__** If deleting of the last snapshots fails, the script
automatically steps to "the snapshot after the last one", and continues.

You can also specify the _minumin number of days_ that are neede before the
script would make a new snapshot of a single volume with option __-m__.

If CRT and PK files are not provided respectively as 'cert.pem' and 'pk.pem'
under directory '/etc/aws' you should specify them both with __-C__ and __-K__


## Installation details
* create dedicated user
* download CRT and PK file (.pem format) and place them in your EC2 instance
**__WARNING__** This files are very important! Please keep them under strict
survellaince (perm 500) and let them be accessed only by authorized users.
* copy this script under the dedicated user home
* try first execution and look via AWS web GUI if a snapshot is created
  for every and each "interesting" EBS volume
* put script in crontab and check if it's still working
* wait next auto-backup and check again if it's working
* have fun and take profit \o/
* pay me a beer :3

### Requirements
You will need perl-JSON librearies to execute this script since every and each
message from AWS API are exchanged (oh, joy!) via JSON format

Note to Cpt. Obvious:
* Perl is a _foundamental requirement_
* You will also need to be __inside__ you AWS instance when this script is
  executed


## ToDo
* implement configuration files
* expand and add new possible customization options based on user needs
* implement logging
* implement error handling
* implement error moritoring and alerting

