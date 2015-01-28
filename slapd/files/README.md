Run this if the ldapscripts.passwd file is ever editted.

	perl -pi -e 'chomp if eof' ldapscripts.passwd

This removes the trailing newline that ldapscripts expects
