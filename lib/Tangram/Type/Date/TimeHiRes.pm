
use strict;

package Tangram::Type::Date::HiRes;

use Tangram::Type::Date;
use Time::Local qw(timegm timelocal);
use Carp;

use vars qw(@ISA);
 @ISA = qw( Tangram::Type::Date );

$Tangram::Schema::TYPES{time_hires} = Tangram::Type::Date::HiRes->new;

sub coldefs
{
    my ($self, $cols, $members, $schema) = @_;
    $self->_coldefs($cols, $members, "TIMESTAMP(6) $schema->{sql}{default_null}");
}

sub get_importer
{
  my $self = shift;
  my $context = shift;
  $self->SUPER::get_importer
      ($context,
       sub { my($iso)=shift;
	     my ($year, $mon, $mday, $hour, $min, $sec, $sec_f, $tz, $tzhouroff, $tzminoff)
		 = ($iso =~ m/^(\d{4})-(\d\d)-(\d\d)T \s?
			       (\d?\d):(\d\d):(\d\d)
			       (?:\.(\d+))? \s?
			      (([+\-]\d+)(?:(\d{2}))?|Z)?$/x)
		     or confess "bad ISO format from internal; $iso";

	     my ($time_t, $usec);
	     $tzhouroff ||= 0;
	     $sec_f ||= "000000";
	     if ( $tz ) {
		 $time_t = timegm($sec, $min, $hour, $mday, $mon, $year);
		 $time_t += $tzhouroff * 3600;
		 if ( $tzminoff ) {
		     if ( $tzhouroff < 0 ) {
			 $time_t -= $tzminoff * 60;
		     } else {
			 $time_t += $tzminoff * 60;
		     }
		 }
	     } else {
		 $time_t = timelocal($sec, $min, $hour, $mday, $mon, $year);
	     }
	     my $sec_f_len = length $sec_f;
	     if ( $sec_f_len != 6 ) {
		 $sec_f *= 10 ** (6 - $sec_f_len);
	     }
	     return [ $time_t, int($sec_f) ];
	   }
      );
}

use POSIX qw(strftime);

sub get_exporter
{
    my $self = shift;
    my $context = shift;
    $self->SUPER::get_exporter
	($context, sub {
	     my $hires_t = shift;

	     # return in ISO8061 form YYYY-MM-DDTHH:MN:SS.SSSSSS+TZ
	     my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)
		 = localtime($hires_t->[0]);

	     my $time = (strftime("%Y-%m-%dT%H:%M:%S.xxxxxx%z",
				  $sec, $min, $hour, $mday, $mon, $year, $wday,
				  $yday, $isdst));

	     $time =~ s{xxxxxx}{sprintf("%.6d", $hires_t->[1])}e;

	     return $time;
     });
}

1;
