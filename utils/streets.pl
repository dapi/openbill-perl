#!/usr/bin/perl
use XBase;
use locale;
my $file = $ARGV[0];
my $table = new XBase "$file" or die XBase->errstr;
my @f = $table->field_names();
my @t = $table->field_types();

#print("÷ÓÅÇÏ ÚÁĞÉÓÅÊ: ".$table->last_record."\n");
my $l=$table->last_record;
my %S;
for (0 .. $table->last_record) {
  my $hr = $table->get_record_as_hash($_);
  foreach (@f) {
    print "$_=",tran($hr->{$_}).",";
    my $s = convert(tran($hr->{STREET}));
    $S{$s}=1;
  }
  $l--;
#  print "\r$l";
  print "\n";
}
#foreach (sort keys %S) {
#  print "$_\n";
#}

sub convert {
  my $s = shift;
  #  $s=~/[^ ](.)(.*)/\U$1\l$2/g;
  return $s;
}

sub tran {
  my @a;
  return undef unless @_;
  foreach (@_) {
    my $a = $_;
    $a=~tr/\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8A\x8B\x8C\x8D\x8E\x8F\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9A\x9B\x9C\x9D\x9E\x9F\xA0\xA1\xA2\xA3\xA4\xA5\xA6\xA7\xA8\xA9\xAA\xAB\xAC\xAD\xAE\xAFàáâãäåæçèéêëìíîïğñ/áâ÷çäåöúéêëìíîïğòóôõæèãşûıÿùøüàñÁÂ×ÇÄÅÖÚÉÊËÌÍÎÏĞÒÓÔÕÆÈÃŞÛİßÙØÜÀÑ³£/;
    push @a,$a;
  }
  return wantarray ? @a : $a[0];
}
