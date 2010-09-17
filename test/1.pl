#!/usr/bin/perl

use MIME::QuotedPrint qw(encode_qp);
use Encode qw(encode);

my $encoded = '"Данил Письменный" <danil@orionet.ru>';
$encoded=~s/([йцукенгшщзхъфываполджэячсмитьбюёЙЦУКЕНГШЩЗХЬФЫВАПОЛДЖЭЯЧСМИТЬБЮ║]+)/qp_encode($1)/egi;
print $encoded;

sub qp_encode {
  my $s = shift;
  return '=?KOI8-R?Q?'.encode_qp($s).'?=';
}
