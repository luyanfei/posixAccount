#!perl -T
use 5.10.1;
use strict;
use utf8;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use Net::LDAP::posixAccount::Manager;
use Encode;

binmode(STDOUT, ':encoding(utf8)');

my $manager = Net::LDAP::posixAccount::Manager->new("test.conf");
ok( defined $manager, "Manager object can be created successfully.");
ok( $manager->maxid("uid"), "maxid method can be called from instance variable.");
dies_ok { Net::LDAP::posixAccount::Manager->maxid("uid"); } 'maxid method cannot called from class name.';
dies_ok { $manager->maxid("abc"); } 'the parameter category of maxid cannot be other strings.';
my $olduid = $manager->maxid("uid",0);
my $incuid = $manager->maxid("uid",1);
ok( $olduid == $incuid, "after increment maxid returns old uid." );
my $newuid = $manager->maxid("uid",0);
ok( $newuid-$olduid == 1, "newuid($newuid) is 1 bigger than olduid($olduid)." );
my $oldgid = $manager->maxid("gid",0);
my $incgid = $manager->maxid("gid",1);
ok( $oldgid == $incgid, "after increment maxid returns old gid." );
my $newgid = $manager->maxid("gid",0);
ok( $newgid-$oldgid == 1, "newgid($newgid) is 1 bigger than oldgid($oldgid)." );

#Test Net::LDAP add duplicate entry.
my $conn = $manager->{connection};
my $msg = $conn->add(
		     $manager->{config}{max_uid_dn},
		     attrs => [
			       cn => "max_uid_number",
			       gidNumber => 20000,
			       objectClass => [ qw /top posixGroup/ ] 
			      ]
		    );
ok( $msg->code == 68, "add already existed dn will get LDAP_ALREADY_EXISTS error code.");

#test mkaccount
my $account = $manager->mkaccount("20130101","托马斯","people","students","info");
$account->{create}->();
$account->{update}->();
my $user = $conn->search(
			 base => $manager->{config}{base},
			 scope => "sub",
			 filter => "(uid=20130101)",
			 sizelimit => 1
			 )->shift_entry;
ok( $user->dn eq "uid=20130101,ou=info,ou=students,ou=people,$manager->{config}{base}" );
ok( decode("utf8",$user->get_value("cn")) eq "托马斯" );
ok( decode("utf8",$user->get_value("sn")) eq "托" );
ok( decode("utf8",$user->get_value("givenName")) eq "马斯" );
ok( $user->get_value("uid") eq "20130101" );

#test mkgroup
my $g1 = $manager->mkgroup("测试分组","groups","students","info");
$g1->{class}->("posixGroup");
$g1->{update}->();
my $group = $conn->search(
			 base => $manager->{config}{base},
			 scope => "sub",
			 filter => "(cn=测试分组)",
			 sizelimit => 1
			 )->shift_entry;
ok( decode("utf8",$group->dn) eq "cn=测试分组,ou=info,ou=students,ou=groups,$manager->{config}{base}" );
ok( decode("utf8",$group->get_value("cn")) eq "测试分组" );

#test associate
$manager->associate('(cn=测试分组)','(uid=20130101)');
my $tuser = $conn->search(
			 base => $manager->{config}{base},
			 scope => "sub",
			 filter => "(uid=20130101)",
			 sizelimit => 1
			 )->shift_entry;
my $tgroup = $conn->search(
			 base => $manager->{config}{base},
			 scope => "sub",
			 filter => "(cn=测试分组)",
			 sizelimit => 1
			 )->shift_entry;
ok( $tuser->get_value("gidNumber") == $tgroup->get_value("gidNumber") );
ok( $tuser->get_value("uid") == $tgroup->get_value("memberUid") );

#delete added test entry.
$manager->delete("(uid=20130101)");
my $search = $conn->search(
			 base => $manager->{config}{base},
			 scope => "sub",
			 filter => "(uid=20130101)",
			 sizelimit => 1
			 );
ok( $search->count == 0 );

$manager->delete("(cn=测试分组)");
my $groupsearch = $conn->search(
			 base => $manager->{config}{base},
			 scope => "sub",
			 filter => "(cn=测试分组)",
			 sizelimit => 1
			 );
ok( $groupsearch->count == 0 );

done_testing();
