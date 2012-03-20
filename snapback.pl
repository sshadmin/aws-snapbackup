#!/usr/bin/env perl
use strict ;
# use warnings ;
use Getopt::Long ;
if ( not eval { require JSON; 1; } ) {
  print "Please install JSON module and make available to current user.\n";
  exit 1;
};

my $script_name = "$0" ;
my $version     = '0.0.1' ;
my $srcLink     = 'https://github.com/sshadmin/aws-snapbackup';

# BEGIN helper function declaration
# actual code is at the end of the file
sub help ;                    # prints help screen
sub trim ;                    # trims space chars after and before string

sub automagic ;               # automagic mode procedure

sub cleanExit ;               # closes the script removing any leftover
                              # (debug file, etc)
sub parseConfigFile ;         # toDo - parse provided config file
# END helper function declaration

# creating vars to store arg values given from CLI
my ( $help , $debug ) ;
my ( %Opts ) ;
my $automagicMode ;
my $minSnapDays=6*(24*60*60) ; #in seconds to e compared with EPOCH time
my $maxSnapCount=4 ;           #number of snapshots pe single EBS volume
my $crtFile='/etc/aws/cert.pem';
my $pkFile='/etc/aws/pk.pem' ;

# BEGIN parsing args #
if ($#ARGV ge 0) {
  Getopt::Long::Configure ("bundling");

  GetOptions(\%Opts,
    'm=i'             =>  \$Opts{minDays}       ,
    'mindays=i'       =>  \$Opts{minDays}       ,

    'x=i'             =>  \$Opts{maxCount}      ,
    'maxcount=i'      =>  \$Opts{maxCount}      ,

    'a'               =>  \$Opts{automagic}     ,
    'automagic'       =>  \$Opts{automagic}     ,

    'C=s'             =>  \$Opts{crtFile}       ,
    'certfile=s'      =>  \$Opts{crtFile}       ,

    'K=s'             =>  \$Opts{pkFile}        ,
    'pkfile=s'        =>  \$Opts{pkFile}        ,

    'r'               =>  \$Opts{includeRootDev},
    'include-root'    =>  \$Opts{includeRootDev},

    'd'               =>  \$Opts{debug}         ,
    'debug'           =>  \$Opts{debug}         ,

    'v'               =>  \$Opts{version}       ,
    'version'         =>  \$Opts{version}       ,

    'h'               =>  \$Opts{help}          ,
    'help'            =>  \$Opts{help}
  );

  if ($Opts{help}) {
    help() ;
    exit 0 ;
  };

  if ($Opts{version}) {
    print $script_name.': version '.$version. "\n";
    print 'Source Code repository:'.$srcLink."\n";
    exit 0 ;
  };

  if ($Opts{debug}) {
    print "-> Debug enabled <-\n";
    $debug = 1 ;
  };

  if ($Opts{automagic}) {
    print "-> Automagic mode enabled <-\n" if($debug);
    $automagicMode = 1 ;
  };

  if ($Opts{minDays}) {
    $minSnapDays=scalar($Opts{minDays})*(24*60*60); # converts in seconds to allow
                                            # comparison with EPOCH time
    print "-> min snapshot days (in seconds) <- $minSnapDays\n" if($debug);
  }

  if ($Opts{maxCount}) {
    $maxSnapCount=$Opts{maxCount};
    print "-> max snapshot instances <- $maxSnapCount\n" if($debug);
  }

  if ($Opts{crtFile}) {
    $crtFile=$Opts{crtFile};
    print "-> AWS certificate file <- $crtFile\n" if($debug);
  }

  if ($Opts{pkFile}) {
    $pkFile=$Opts{pkFile};
    print "-> AWS private key file <- $pkFile\n" if($debug);
  }

} else {
  print "  Error:\n";
  print "    No argument given.. please provide at least one argument\n" ;
  help() ;
  exit 0 ;
};

# default vars
my $ec2DataUrl='http://169.254.169.254/latest/' .
               'dynamic/instance-identity/document';
my $ec2DataResponse=qx['curl' '-s' $ec2DataUrl];
if ($debug) {
  print "Response: " .$ec2DataResponse."\n";
}
my $instanceDataRef=decode_json $ec2DataResponse;
my $instanceDataText=from_json($ec2DataResponse, {utf8 => 1});
my $instanceId=$instanceDataRef->{"instanceId"};
my $instanceRegion=$instanceDataRef->{"region"};
if ($debug) {
  print "instanceId: " . $instanceId . "\n" ;
  print "region: " . $instanceRegion . "\n" ;
}

if ($automagicMode){
  automagic() ;
}


###############################################################################
sub help {
  print "
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
  -r,  --include-root             *O* Include root devices in snapshot backup
  -d,  --debug                    *O* Prints LOTS of debug info on stdout
  -h,  --help                     *O* Prints this help screen\n";
}

sub cleanExit {
  exit ( $1 || 1 ) ;
}

sub trim {
  my $string = $_[0] || '' ;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  return $string
}

sub convertDate {
  my  $localDate=$_[0] ;
      $localDate=~s/\+[0-9]*//; #get rid of the +0000 at the end of dates
  my $cmd=('date +%s -d ' . $localDate);
  my $out=qx($cmd);
  return trim($out);
}

sub automagic {
  my $assignedVols=retrieveAssignedVols();
  if ($debug) {
    print "Assigned EBS vols :\n";
    print "$assignedVols\n" ;
  }
  my $localDevices=collectLocalDevices();
  if ($debug) {
    print "Local detected devices:\n" ;
    foreach my $dev (keys %$localDevices){
      print '  ' . $dev .' -> '. $localDevices->{$dev} . "\n" ;
    }
  }
  my $EBSvolsInUse=filterEBSVols($assignedVols,$localDevices);
  if ($debug) {
    print "Local EBS devices:\n" ;
    foreach my $dev (keys %$EBSvolsInUse){
      print $dev . "\n";
      print 'volID  -> ' . $EBSvolsInUse->{$dev}->{volID} . "\n";
      print 'device -> ' . $EBSvolsInUse->{$dev}->{device} . "\n";
      # print 'date   -> ' . $EBSvolsInUse->{$dev}->{date} . "\n";
    }
  }
  print "maxSnapCount -> $maxSnapCount \n" if ($debug);
  my $result=backupNow($EBSvolsInUse);

  ################
  # automagic routines code
  ################
  # retrieve attached volumes
  sub retrieveAssignedVols {
    my @cmd=('ec2-describe-volumes',
              '-K '.$pkFile,'-C '.$crtFile,'--region '.$instanceRegion,
              '-F attachment.instance-id='.$instanceId);
    my $cmdStr = join(' ',@cmd);
    print "Retrieve assigned cmd is --> " . $cmdStr ."\n" if ($debug) ;
    my $cmdOutput=qx($cmdStr);
    return $cmdOutput;
  }
  # collect mtab/fstab devices
  sub collectLocalDevices {
    my $localDevs={};
    my $sysDevRegex='^none$|^proc$|^sysfs$|^udev$|^devpts$';
    my $sysMntPoint='none|/proc|/sys|^/dev$|^/run$';
    if (!$Opts{includeRootDev}){;
       $sysMntPoint.='|^/$' ;
       print "-> / device snapshot included <-\n" if($debug);
    };
    my @deviceFiles=( '/etc/fstab', '/etc/mtab');
    foreach my $file (@deviceFiles){
      open(my $FILE, "<", $file) or die $!;
      print "$file opened correctly\n" if ($debug);
      while(my $line=<$FILE>){
        my @splittedLine=split(/\s+/,$line);
        my $dev=$splittedLine[0];
        my $mntPoint=$splittedLine[1];
        if (($dev !~ /$sysDevRegex/) && ($mntPoint !~ /$sysMntPoint/) &&
            (! defined($localDevs->{dev}))) {
          print "  Dev: $dev -> mntPoint: $mntPoint\n" if ($debug);
          $localDevs->{$dev}=$mntPoint;
        }
      };
      close($FILE);
    }
    return $localDevs;
  }
  # check which device is an EBS attached volume
  sub filterEBSVols {
    my $assignedVols=shift ;
    my $localDevs=shift;
    print "Assigned -> $assignedVols\n" if ($debug);
    my $EBSvols={};
    my @splittedVols = split(/\n/,$assignedVols);
    @splittedVols = grep({$_ =~ /attached/} @splittedVols);
    foreach my $vol (@splittedVols){
      print "vol -> $vol\n" if ($debug) ;
      my @volProp=(split(/\s+/,$vol));
      print "volPro -> @volProp\n" if ($debug) ;
      my $normalizeDevName=$volProp[3];
      $normalizeDevName=~ s/\/dev\/sd/\/dev\/xvd/;
      print "normalizeDevName -> $normalizeDevName\n" if ($debug) ;
      if ($normalizeDevName and defined($localDevs->{$normalizeDevName})) {
        $EBSvols->{$normalizeDevName}->{volID}=$volProp[1];
        $EBSvols->{$normalizeDevName}->{device}=$volProp[3];
        # $EBSvols->{$normalizeDevName}->{date}=$volProp[5];
      };
    };
    return $EBSvols;
  }
  # for each attached volume
  sub backupNow {
    my $EBSvolsInUse=shift;
    my @resultActions=();

    my $validSnapshots=();
    print 'PresentSnaps :'."\n" if($debug);
    foreach my $vol (keys %$EBSvolsInUse){
      @{$validSnapshots->{$vol}}=retrieveSnaps($EBSvolsInUse->{$vol}->{volID});
      if($debug) {
        print 'PostFilteringSnaps :'."\n" ;
        foreach my $snap (@{$validSnapshots->{$vol}}){
          print '  snapID ->' . $snap->{snapID} ."\n";
          print '  volID  ->' . $snap->{volID} ."\n";
          print '  status ->' . $snap->{status} ."\n";
          print '  date   ->' . $snap->{date} ."\n";
        }
      }
      # here var max snap count gets modified
      print "maxSnapCount -> $maxSnapCount \n" if ($debug);
      @{$validSnapshots->{$vol}}=updateSnaps(@{$validSnapshots->{$vol}},
                                             $minSnapDays,$maxSnapCount);
      if($debug) {
        print 'UpdatedSnaps :'."\n" ;
        foreach my $snap (@{$validSnapshots->{$vol}}){
          print '  snapID ->' . $snap->{snapID} ."\n";
          print '  volID  ->' . $snap->{volID} ."\n";
          print '  status ->' . $snap->{status} ."\n";
          print '  date   ->' . $snap->{date} ."\n";
      }}
    }
    # collect snapshots
    sub retrieveSnaps {
      my $volumeId=$_[0];
      my @cmd=('ec2-describe-snapshots',
                '-K '.$pkFile,'-C '.$crtFile,'--region '.$instanceRegion,
                '-F volume-id='.$volumeId);
      my $cmdStr = join(' ',@cmd);
      print "Retrieve snapshots cmd is --> " . $cmdStr ."\n" if ($debug) ;
      my $cmdOutput=qx($cmdStr);
      print 'PreFiltering :'."\n" if($debug);
      my @validSnapshots=();
      foreach my $line(split(/\n/,$cmdOutput)) {
        if ($debug){
          print '  -> '.$line ."\n";
        }
        my @lineValues=(split(/\s+/,$line));
        my  $snap->{snapID}=$lineValues[1];
            $snap->{volID}=$lineValues[2];
            $snap->{status}=$lineValues[3];
            $snap->{date}=convertDate($lineValues[4]);
        if($lineValues[3] =~ /^completed$/){
          push(@validSnapshots,$snap);
        }
      }
      if (scalar(@validSnapshots)>1){
        @validSnapshots=sort { $a->{date} <=> $b->{date} } @validSnapshots;
      }
      return @validSnapshots;
    }
    # create a newSnap
    sub createNewSnap {
      my $volumeId=$_[0];
      my $snapDescription='Create by '.$script_name.' script ';
      my $hostnameCmd="hostname -f";
      my $nowCmd="date -R";
      my $now=qx($nowCmd);
      my $hostname=qx($hostnameCmd);
         $snapDescription.='by '.trim($hostname).' ';
         $snapDescription.='on '.trim($now).' ';
      # check if ec2-consistent-snapshot is present as a preferred choice
      my @cmd;
      my $consistentSnapshot=0;
      if ($consistentSnapshot) {
        @cmd=();
      } else {
        @cmd=('ec2-create-snapshot',
                '-K '.$pkFile,'-C '.$crtFile,'--region '.$instanceRegion,
                $volumeId,
                '-d "'.$snapDescription.'"');
      };
      my $cmdStr = join(' ',@cmd);
      print "Create snapshot cmd is --> " . $cmdStr ."\n" if ($debug) ;
      qx('sync');
      my $cmdOutput=qx($cmdStr);
      return $cmdOutput ;
    }
    # create a newSnap
    sub deleteOldSNap {
      my $volumeId=$_[0];
      my @cmd=('ec2-delete-snapshot',
                $volumeId,
                '-K '.$pkFile,'-C '.$crtFile,'--region '.$instanceRegion);
      my $cmdStr = join(' ',@cmd);
      print "Delete snapshot cmd is --> " . $cmdStr ."\n" if ($debug) ;
      my $cmdOutput=qx($cmdStr);
      return $cmdOutput ;
    }
    # if last one > 7 days then backup
    # if $#snapshots > 4 then delete oldest
    sub updateSnaps {
      my @presentSnaps=$_[0];
      # my $minSnapDays=$_[1]; #need fix, value becomes an Hash ref inside sub
      # my $maxSnapCount=$_[2]; #need fix, value becomes an Hash ref inside sub
      my @resultActions=();
      # check if last snap is > 7 days ago
      my $lastSnap=$presentSnaps[$#presentSnaps];
      my $now=convertDate('now');
      if ($debug){
        print "Last Date -> ".$lastSnap->{date}."\n";
        print "Now -> ".$now."\n";
        print "Min Days -> ".$minSnapDays."\n";
        print "Min difference -> ".($now-$minSnapDays)."\n";
        print "maxSnapCount -> ".$maxSnapCount."\n";
      };
      if ($lastSnap->{date} < ($now-$minSnapDays)){
        #create new snapshot
        print "Adding a new snapshot" if ($debug);
        my $createOutput=createNewSnap($lastSnap->{volID});
        push(@resultActions,'newSnap');
      };
      # check if number of snaps > 4 then delete oldest
      @presentSnaps=retrieveSnaps($lastSnap->{volID});
      my $snapIdx=0;
      print "scalar(\@presentSnaps)-> ".scalar(@presentSnaps)."\n" if ($debug);
      print "maxSnapCount -> $maxSnapCount \n" if ($debug);
      while(scalar(@presentSnaps) > $maxSnapCount){
        my $oldSize=scalar(@presentSnaps);
        my $oldestSnap=$presentSnaps[$snapIdx];
        print "Deleting old snapshot".$oldestSnap->{snapID} if ($debug);
        my $deleteOutput=deleteOldSNap($oldestSnap->{snapID});
        push(@resultActions,'delete');
        @presentSnaps=retrieveSnaps($lastSnap->{volID});
        my $newSize=scalar(@presentSnaps);
        # if length does not decrease then move over
        if($newSize >= $oldSize){
          $snapIdx++;
        };
      };
      return @presentSnaps ;
    }
  }
}