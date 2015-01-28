=============
slapd-formula
=============

A saltstack formula that installs slapd on Ubuntu 12.04 and possibly
Debian Wheezy.

.. note::

    See the full `Salt Formulas installation and usage instructions
    <http://docs.saltstack.com/en/latest/topics/development/conventions/formulas.html>`_.

Available states
================

.. contents::
    :local:

``slapd.server``
----------------

Installs the slapd server package as well as ldapscripts to help ease
administration. Self signed certs are also setup to encrypt connections
between slapd server and clients.

``slapd.pam``
----------------

Installs the ldap pam client packages and configures pam to authenticate
against slapd server.
