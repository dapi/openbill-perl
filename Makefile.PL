require 5.8.3;
use ExtUtils::MakeMaker;
use ExtUtils::Manifest qw(maniread);

ExtUtils::Manifest::mkmanifest;

my $version=1;
my $revision=`svnversion -n .`;
$revision=~s/\:/\./g;
#my $CONFIG_DIR='/usr/local/etc';

unlink 'MANIFEST.bak' if -f 'MANIFEST.bak';
unlink 'Makefile.old' if -f 'Makefile.old';

sub MY::libscan
  {
    my($self,$path) = @_;

    return ''
      if ($path =~ m:/(RCS|CVS|SCCS)/: ||
	  $path =~ m:[~%.]$: ||
	  $path =~ m:\.(orig|rej|nfs)$:
	 );

    $path;
  }

WriteMakefile(
	      NAME	   => 'openbill',
              VERSION      => "$version.$revision",
	      AUTHOR       => 'Danil Pismenny <danil@pismenny.ru>',
	      ABSTRACT     => 'Open Billing System',
	      PMLIBDIRS    => [ 'lib', '$(BASEEXT)', 'openbill' ],
	      PREREQ_PM    => {
                               #                               'CGI'           => 2.752,
                               #				'Apache'        => 1.27,
                               #				'Class::Fields' => 0.14,
                               'XML::LibXML'   => 1.31,
                               #				'XML::LibXSLT'  => 1.31,
                               'DBI'           => 1.20,
                               'URI'           => 1.12,
                               #				'IPC::ShareLite'=> 0.08,
                               'Text::FormatTable'=>0.01,
                               'IPC::Open3'=>0.01,
                               'Text::Shellwords'=>1.02,
 #                              'Term::ReadLine::Gnu'=>1.10, версия не вычисляется
#                               'LockFile::Simple'=>0.2.5,# - вызывает ошибку при make dist
                               'Time::HiRes'=>1.50,
                               'Digest::MD5'=>2.16,
                               'SOAP::Lite'=>0.60,
                               'Date::Handler'=>1.0,
                               'Date::Parse'=>1.1302,
                               'dpl::System'=>1.7,
                               'Log::Log4perl'=>0.35,
                               'Data::Dumper'=>2.101,
                               'Number::Format'=>1.45,
                               'Template'=>2.08,
                               'Email::Send'=>1.43,
                               'IO::String'=>1.02,
                               'Text::Iconv'=>1.2,
                               'MIME::Lite'=>2.117,
                               'Date::Calc'=>0,
                               'LockFile::Simple'=>0,
                               'MIME::Words'=>5.416,
                               'Data::Serializer'=>0.17,
                               'NetAddr::IP'=>0, # Из тестов

			      },

	      dist => {COMPRESS=>'bzip2', SUFFIX=>'.bz2'},
              #	      clean => {FILES=>'*.bz2*'}
	     );
