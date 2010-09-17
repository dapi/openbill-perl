#!/usr/bin/perl
use locale;
use POSIX qw(locale_h);
use openbill::DataType::DateTime;
use dpl::Db::Database;
use dpl::Error;
use dpl::Db::Database;
use dpl::Db::Table;
use dpl::Db::Filter;
use dpl::System;
use strict;
use MIME::Parser;
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use IO::Scalar;

dpl::System::Define('openbill','/home/danil/projects/openbill/etc/system.xml');
my @local=GetLocals();
my $db = db();
$db->Connect();

setlocale(LC_ALL,"ru_RU.KOI8-R");

print "Parse charlie V0.4\n";

#if (@ARGV) {
		#  foreach (@ARGV) {
    # 1 - выводить статистику на экран
    # 2 - выводить сам архив
	#	print STDERR "$_\n";
	#    parseMIME($_,2);
	#  }
#} else {
#  parseMIME('',2);
#}


foreach (@ARGV) {
  my $res = parseMIME($_,3);
  next unless $res;
  if ($res==1) {
    arcFile($_);
  } else {
    arcFile($res->{file})
      if SaveToDB($res);
  }
  print "\n";
}


# 0 - выводить на экран статистику
# 1 - писать в файл
# 2 - выводить на экран
# 3 -


sub parseMIME {
  my ($file,$just_unzip) = @_;
  my $parser = new MIME::Parser;
  $parser->ignore_errors(1);
  #$parser->output_dir("/tmp");
  $parser->output_to_core(1);
  $parser->extract_uuencode(1);
  my $entity = $file ? $parser->parse_open($file) : $parser->parse(\*STDIN);
  print "Parse: $file\n" if $file;
  #  $entity->dump_skeleton;
  my @a=$entity->parts;
  my $e=$a[0];
  unless ($e) {
#    die $entity->preamble();
    my $body = $entity->bodyhandle();
    my $str = $body->as_string();
    if ($str=~/Traffic/) {
      print "$str\n";
      return 1;
    } else {
      print STDERR "No parts in message\n";
      return undef;
    }
  }

  #  die $e->head()->get('Content-Disposition');
  my $attachhead = $e->head();
  my $head = $entity->head();
  my $date = $head->get('Date',0);
  $date=~s/\n|\r$//g;
  unless ($attachhead) {
    print STDERR "No attaches in message\n";
    return undef;
  }
  my $filename = $attachhead->recommended_filename();
  my $zipData;
  die "No MIME" unless $e;
  #print "Unzip data: ";
  my $IO = $e->open("r") || die "open body: $!";
  while (defined($_ = $IO->getline)) {
    $zipData.=$_;
    print $_ if $just_unzip==2;
  }
  $IO->close() || die("close I/O handle: $!");
  return 1 if $just_unzip==2;
  my $zipFile = new IO::Scalar \$zipData;
  my $data;
  my $dataFile = new IO::Scalar \$data;
  my $zip = Archive::Zip->new();
  my $status = $zip->readFromFileHandle( $zipFile );
  die "Read of zip failed\n" if $status != AZ_OK;
  foreach my $member ($zip->members) {
    $member->desiredCompressionMethod(COMPRESSION_STORED);
    my $status = $member->extractToFileHandle($dataFile);
    #  print $member->fileName();
    die "Zip status: $status" if $status != AZ_OK;
  }
  $dataFile->setpos(0);
  unless ($filename=~s/l\d\.zip// || $filename=~s/l\d.all.out.zip//) {
    print STDERR "Unknown MIME file name: $filename\n";
    return undef;
  }
  $date=~s/\S+\,\s+//;
  $date=~s/(\d+)\s(\S+)\s(\d+).*/$3_$2_$1/;
  return {file=>$file,filename=>$filename,
          date=>$date,data=>$data};
#
#   if ($filename=~s/rl\d\.zip//) {
#     if ($filename) {
#       $date=~s/\S+\,\s+//;
#       $date=~s/(\d+)\s(\S+)\s(\d+).*/$3_$2_$1/;
#       if ($write_to_disk==3) {
#         SaveToDB($filename,$data);
#         arcFile($file);
#       } elsif ($write_to_disk) {
#         print "$filename.$date";
#         showStats($data,"$filename.$date");
#         arcFile($file);
#       } else {
#         print "$filename\n";
#         showStats($data);
#       }
#       #      return ($dataFile,$filename);
#     } else {
#       print STDERR "Bad MIME file name: $filename\n";
#     }
#   } else {
#     print STDERR "Unknown MIME file name: $filename\n";
#   }
#   return undef;
}

sub SaveToDB {
  my ($res) = @_;

  my %cache;
  my %all;
  print "Save to DB $res->{filename} @ $res->{date}\n";
  my $f = new IO::Scalar \$res->{data};
  my $date;
  my %ips;
  my $ip;
#  while (<>) {
  while (<$f>) {
    s/\s+$//g;
#    print "$_=\n";
    next if /^(ALL)?SUMM/;
 #   next if /^SUMM/;
    next unless $_;
    if (my ($from,$fp,$to,$tp,$type,$bytes)=/^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {

      next if $from eq 'FROM';
      die "unknown date" unless $date;
      unless ($ip) {
        $ips{$from}+=1;
        $ips{$to}+=1;
        unless ($ips{$from}==$ips{$to}) {
          $ip = $ips{$from}>$ips{$to} ? $from : $to;
        }
      }
      if (isLocal($from) && isLocal($to)) {
        $cache{$date}->{1}+=$bytes;
      } else {
        $cache{$date}->{0}+=$bytes;
      }
    } elsif (s/.+trafd.*chuvashia.ru.+(\D{3})(\d+)/$1$2/) {
      if ($date) {
        print "$cache{$date}->{0} / $cache{$date}->{1}\n";
        $all{0}+=$cache{$date}->{0};
        $all{1}+=$cache{$date}->{1};
      }
      $date=$_;

      print "Day $date: ";
      $cache{$date}={};
    } else {
      die "Unknown line $_";
    } ;
  }
  if ($date) {
    print "$cache{$date}->{0} / $cache{$date}->{1}\n";
    $all{0}+=$cache{$date}->{0};
    $all{1}+=$cache{$date}->{1};
  }

  print "ALL: $all{0} / $all{1}\n";
  my %months = (JAN=>1,FEB=>2,MAR=>3,APR=>4,MAY=>5,JUN=>6,JUL=>7,AUG=>8,SEP=>9,OCT=>10,NOV=>11,DEC=>12);
  my $rid = LoadRouter($res->{filename},$ip) || die 'no router';
  my $table = table('prov_day_traffic');
  print "Save: ";
  foreach (sort keys %cache) {
    my ($m,$d)=/^(...)(\d+)/;
    die "unknown month: '$m'" unless $months{uc($m)};
    my $date = new Date::Handler({ date => {year=>2006,
                                            day=>$d,
                                            month=>$months{uc($m)}},
                                   locale=>'ru_RU.KOI8-R',
                                   time_zone => 'Europe/Moscow'});
    $table->Delete({date=>$date,
                    prov_router_id=>$rid});
    $table->Create({date=>$date, prov_router_id=>$rid, class=>0, bytes=>$cache{$_}->{0}});
    $table->Create({date=>$date, prov_router_id=>$rid, class=>1, bytes=>$cache{$_}->{1}})
  }
  db()->Commit();

#  my $output = "$res->{filename}_$res->{date}";
#  open(FILE,">$output") || die "can't open $output";
#  print FILE $res->{data}  || die "can't write $output";
#  close(FILE) || die "can't close $output";


  print "OK\n";
  return 1;
}

sub LoadRouter {
  my ($router_name,$ip) = @_;
  my $res = table('prov_router')->Load({name=>$router_name});
  if ($res) {
    table('prov_router')->Modify({lasttime=>today()},$res->{id});
  } else {
    print "New router: $router_name - $ip\n";
    $res = table('prov_router')->Create({name=>$router_name,
                                         ip=>$ip});
  }
  return $res->{id};
}

sub isLocal {
  my $ip = shift;
  foreach (@local) {
    return 1 if $_ eq $ip;
  }
  return 0;
}


sub arcFile {
  my $file =  shift;
  my $path = $file;
  my $old = $file;
  $path=~s/([^\/]+)$//;
  $file=$1;
  $path="$path../arc/";
  print "Archive: ";
  die("Can't rename $old to $path$file")
    unless rename($old,$path.$file);
  print "OK\n";
}

sub showStats {
  my ($data,$output) = @_;
  if ($output) {
    open(FILE,">$output") || die "can't open $output";
#    while (<$file>) {
      print FILE $data  || die "can't write $output";
#        if $_=~/\S+/;
#    }
    close(FILE) || die "can't close $output";
  } else {
    print $data;
#    while (<$file>) {
#      print "$_"
#        if $_=~/\S+/;
#    }
  }
}


sub GetLocals {
 my @a =  ('217.107.177.196', # www.orionet.ru
           '217.107.177.162', # dapi /vodoprovod
           '217.107.177.187', # gubar / extreem
           '217.107.177.3',   # antonov, nasja
           '217.107.177.6',   # jarmorochnaya
           '217.107.177.180', # project
           '217.107.177.185', # chps
           '217.107.177.2',   # mspr12
           '10.20.30.9',      # shalnov
          );
 my %h = map {$_=>1} @a;

 my $list = table('router')->List();
 foreach (@$list) {
   $h{$_->{ip}}=1;
   $h{$_->{real_ip}}=1;
 }
 return sort keys %h;
}
