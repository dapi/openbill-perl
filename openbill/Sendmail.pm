package openbill::Sendmail;
use Template;
use Template::Filters;
use strict;
use Error qw(:try);
use MIME::Lite;
use MIME::Words;
use IO::String;
use openbill::Utils;
use dpl::Db::Table;
use dpl::Log;
use dpl::Error;
use dpl::Config;
use dpl::Context;
use dpl::System;
use dpl::XML;
use Email::Valid;
use Email::Send qw[Sendmail Qmail]; #SMTP
use Exporter;
use vars qw(@ISA
            @EXPORT);

@ISA=qw(Exporter
        openbill::Base);

@EXPORT=qw(sendmail
           notify);

sub notify {
  my ($name,$data,$mt)=@_;
  return undef;
  my $nodes = config()->root()->findnodes("./notifies/notify[\@name='$name']/*");
  unless ($nodes || @$nodes) {
    logger()->debug("Не найден notify [$name]");
    return undef;
  }

  my %o={message_type=>$mt};
  foreach (@$nodes) {
    my $nodename=xmlDecode($_->nodeName());
    if ($nodename eq 'mail') {
      $data->{email}=xmlDecode($_->getAttribute('email'));
      my $templ = $name; # TODO templ from email attribute;
      if ($data->{email} eq 'client') {
        fatal("Данные по клиенту для пересылки ему письма не переданы в notify")
          unless $data->{client};
        $data->{name} = $data->{client}->{contact_name};
        $data->{email} = $data->{client}->{contact_email};
        $o{client_id} = $data->{client}->{id};
      } else {
        $data->{name} = xmlDecode($_->getAttribute('name'))
          if $_->hasAttribute('name');
      }

      if ($data->{email} ne 'none' && Email::Valid->address($data->{email})) {
        my $res = sendmail($templ,$data,{message_type=>$mt});
      }

    } else {
      fatal("Unknown notify node name: '$nodename'");
    }
  }
}

sub sendmail {
  my ($templ,$data,$options)=@_;
  # return undef;
  $options={} unless $options;
  $data={} unless $data;
  fatal("Не указан шаблон") unless $templ;
  #  my $sender=xmlDecode(config()->root()->findnodes('./mailer/sender')->pop()->textContent());
  my $output;
  $data->{today}=today()
    unless $data->{today};
  #  print "Посылаю письмо для абонента: ".$self->GetName()."\n" if setting('terminal');
  my $t = GetTemplate($templ);
  my $filters = Template::Filters->new({
                                        FILTERS => {
                                                    bytes =>  \&openbill::Utils::filter_bytes,
                                                    money =>  \&openbill::Utils::filter_money,
                                                    money_balance =>  \&openbill::Utils::filter_money_balance,
                                                    inet_ntoa => \&openbill::Utils::filter_inet_ntoa,
                                                    date =>  \&openbill::Utils::filter_date,
                                                    time =>  \&openbill::Utils::filter_time,
                                                   },
                                       });
  my $tt = Template->
    new(%$options,
        #       <COMPILE_DIR>/tmp/ttc/</COMPILE_DIR>
        #       <COMPILE_EXT>.ttc</COMPILE_EXT>
        LOAD_FILTERS=>$filters,
        INTERPOLATE=>1,
        # POST_CHOMP=>1,
        # PRE_CHOMP=>1,
        RELATIVE=>1,
        ABSOLUTE=>1,
        TRIM=>1,
        AUTO_RESET=>0,
	INCLUDE_PATH=>directory('mail_template'),
	OUTPUT=>\$output) || fatal('Немогу инициализировать наблон',Template->error());
#  $Email::Send::Qmail::QMAIL='/var/qmail/bin/qmail-inject';
  $tt->process($t,$data)
    || fatal('Ошибка работы шаблона',$tt->error());
  my $string = IO::String->new($output);
  my $is_text;
  my $text;
  my @keys;
  while (<$string>) {
    s/\n|\r//g;
    if ($is_text) {
      $text.="$_\n";
    } elsif (!$_) {
      $is_text=1;
    } else {
      my ($key,$value)=/^([^:]+):\s+(.*)$/;# || die "error";
      #      die "$key , $value";
      push @keys,[$key,$value];
  #    print STDERR "$key: $value\n";
    }
  }
  my $msg = MIME::Lite->build(TYPE=>'TEXT',
                              Data=>$text);
  $msg->attr('content-type','text/plain');
  $msg->attr('orionet_email',$data->{email});
  $msg->attr('orionet_client',$data->{client}->{client_id})
    if $data->{client}->{client_id};
  $msg->attr('content-type.charset','koi8-r');
  foreach my $v (@keys) {
    $msg->add($v->[0],enc($v->[1]));
  }
  $msg->add("X-Sender","OpenBill v$openbill::Server::VERSION");
#  $msg->add("From",'client@orionet.ru');
  #  $msg->send("sendmail", "/usr/lib/sendmail -t -oi -oem");
#  $msg->send("sendmail", "/usr/lib/sendmail -fclient@orionet.ru -Fclient@orionet.ru");
  $msg->send("sendmail", SetSender=>1);
  my $data = $msg->as_string();
  table('message_log')->Create({client_id=>$options->{client_id},
                                message_type=>$options->{message_type},
                                template=>$templ,
                                datetime=>today(),
                                data=>$data});

}

sub enc {
  my $rawstr = shift;
  my $email;
  if ($rawstr=~s/(^[a-z0-9-_@.]+\s+)//i) {
    $email=$1;
  }
  my $NONPRINT = "\\x00-\\x1F\\x7F-\\xFF ";
  $rawstr =~ s{([$NONPRINT]{1,10})}{
    MIME::Words::encode_mimeword($1, 'B', 'koi8-r');
  }xeg;
  $email.$rawstr;
}

sub GetTemplate {
  my $templ = shift;
  my $root = config()->root();
  my $node = $root->findnodes("./templates/mail[\@name='$templ']")->pop();
  return error("Шаблон письма '$templ' ненайден") unless $node;
  my $fnode = $node->findnodes("./file")->pop() ||
    return error("Не найден имя файла шаблона '$templ' ненайден");
  return directory('mail_template').xmlDecode($fnode->textContent());
}

1;
