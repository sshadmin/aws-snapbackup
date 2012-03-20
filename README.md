# AWS - snapBackup - Snapshot Based Backup for EC2

This script is foundamentally made to take attached EBS volumes of your EC2
Instance and make some snapshots **automagically**.

You can specify the _maximum amount of snapshots_ you want to retain for
a particoular EBS Volume with option __-x__, if _at the end_ of the process
there would be more than the specificied value, the script tries to delete the
oldest one.. if resulting amount is still higher than threshold it continues
to delete the oldest snapshot till the desired quantity is reached.

You can also specify the _minumin number of days_ that are neede before the
script would make a new snapshot of a single volume with option __-m__.

If CRT and PK files are not provided respectively as 'cert.pem' and 'pk.pem'
under directory '/etc/aws' you should specify them both with __-C__ and __-K__

### WARNING 1
If deleting of the last snapshots fails, the script automatically steps
to "the snapshot after the last one", and continues.

### WARNING 2
At the moment the script is very slow and takes approximately 1-3 minutes
to complete.. This is mainly due to the slow answer time of AWS API but
we have plans to make things better in future releases.


## Help

    Usage:
      ./snapback.pl [-a|-h]
    Additional options   :
      [-m <days>] [-x <count>] [-C <file>] [-K <file>]
    Debug & Help options :
      [-d]

    Description:

    Options Legend :
      *M* - Mandatory
      *O* - Optional

    Options :
    -a,  --automagic                *O* Enables Automagic(R) mode.. at
                                        the moment this is the only choice
    -m,  --mindays     <days>       *O* Specify minimum amount of days that
                                        have to be passed since last backup
                                             to create a new snapshot
    -x,  --maxcount    <number>     *O* Specify the maximum amount of
                                        snapshots for a single EBS volume
    -C,  --crtfile     <file>       *O* Specify the AWS certificate file
    -K,  --pkfile      <file>       *O* Specify the AWS private key file
    -d,  --debug                    *O* Prints LOTS of debug info on stdout
    -h,  --help                     *O* Prints this help screen


## Installation details
* create dedicated user
* download CRT and PK file (.pem format) and place them in your EC2 instance

**__WARNING__** These files are very important! Please keep them under strict
survellaince (perm 400 or 440) and let them be accessed only by authorized
users.

* copy this script under the dedicated user home
* try first execution and look via AWS web GUI if a snapshot is created
  for every and each "interesting" EBS volume
* put script in crontab and check if it's still working
* wait next auto-backup and check again if it's working
* have fun and take profit \o/
* pay me a beer :3

### Requirements
* You will need perl-JSON libraries to execute this script since every and each
  message from AWS API are exchanged (oh, joy!) via JSON format
* If you have __ec2-consistent-snapshot__ utility installed and available it
  will be used to create snapshots (to Do)

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
* add ec2-consistent_snapshot support if available

