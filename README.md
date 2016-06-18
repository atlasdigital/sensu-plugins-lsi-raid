## Sensu-Plugins-lsi-raid

[![Build Status](https://travis-ci.org/atlasdigital/sensu-plugins-lsi-raid.svg?branch=master)](https://travis-ci.org/atlasdigital/sensu-plugins-lsi-raid)
<!-- [![Gem Version](https://badge.fury.io/rb/sensu-plugins-snmp.svg)](http://badge.fury.io/rb/sensu-plugins-snmp) -->
<!-- [![Code Climate](https://codeclimate.com/github/sensu-plugins/sensu-plugins-snmp/badges/gpa.svg)](https://codeclimate.com/github/sensu-plugins/sensu-plugins-snmp) -->
<!-- [![Test Coverage](https://codeclimate.com/github/sensu-plugins/sensu-plugins-snmp/badges/coverage.svg)](https://codeclimate.com/github/sensu-plugins/sensu-plugins-snmp) -->
<!-- [![Dependency Status](https://gemnasium.com/sensu-plugins/sensu-plugins-snmp.svg)](https://gemnasium.com/sensu-plugins/sensu-plugins-snmp) -->

## Functionality
This plugin provides facilities for monitoring SNMP to iterate through LSI
MegaRAID statistics and reports on certain metrics.

## Files
 * bin/check-snmp-lsi-raid.rb

## Usage
check-snmp-lsi-raid -h host -C community -S statistic -w warning -c critical

## Installation

[Installation and Setup](http://sensu-plugins.io/docs/installation_instructions.html)

## Notes
