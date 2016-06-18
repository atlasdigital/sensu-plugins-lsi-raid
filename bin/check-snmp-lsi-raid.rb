#!/usr/bin/env ruby
# Check LSI MegaRAID
# ===
#
# This plugin provides facilities for monitoring SNMP to iterate through LSI
# MegaRAID statistics and reports on certain metrics.
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: snmp
#
# USAGE:
#
#   check-snmp-lsi-raid -h host -C community -S statistic -w warning -c critical
#
# LICENSE:
#
#   Author Dru Goradia, Atlas Digital LLC
#
# Released under the same terms as Sensu (the MIT license); see LICENSE for
# details.

require 'sensu-plugin/check/cli'
require 'snmp'
require 'json'

class CheckSnmpLsiRaid < Sensu::Plugin::Check::CLI
  option :host,
         short: '-h host',
         default: '127.0.0.1'

  option :community,
         short: '-C community',
         default: 'public'

  option :statistic,
         short: '-S statistic'

  option :warning,
         short: '-w warning'

  option :critical,
         short: '-c critical'

  option :snmp_version,
         short: '-v version',
         description: 'SNMP version to use (SNMPv1, SNMPv2c (default))',
         default: 'SNMPv2c'

  option :timeout,
         short: '-t timeout (seconds)',
         default: '1'

  option :debug,
         short: '-D',
         long: '--debug',
         description: 'Enable debugging to assist with inspecting OID values / data.',
         boolean: true,
         default: false

  def oid(stat)
    oids = {
      pd_index:         '1.3.6.1.4.1.3582.4.1.4.2.1.2.1.1',
      vd_state:         '1.3.6.1.4.1.3582.4.1.4.3.1.2.1.5',
      pd_state:         '1.3.6.1.4.1.3582.4.1.4.2.1.2.1.10',
      media_err_count:  '1.3.6.1.4.1.3582.4.1.4.2.1.2.1.7',
      other_err_count:  '1.3.6.1.4.1.3582.4.1.4.2.1.2.1.8',
      pred_fail_count:  '1.3.6.1.4.1.3582.4.1.4.2.1.2.1.9'
    }

    oids[stat.to_sym]
  end

  def state(stat, code)
    states = {
      :pd_state => {
        0 =>    'Unconfigured-good',
        1 =>    'Unconfigured-bad',
        2 =>    'Hot-spare',
        16 =>   'Offline',
        17 =>   'Failed',
        20 =>   'Rebuild',
        24 =>   'Online',
        32 =>   'Copyback',
        64 =>   'System',
        128 =>  'UNCONFIGURED-SHIELDED',
        130 =>  'HOTSPARE-SHIELDED',
        144 =>  'CONFIGURED-SHIELDED'
      },
      :vd_state => {
        0 => 'Offline',
        1 => 'Partially Degraded',
        2 => 'Degraded',
        3 => 'Optimal'
      }
    }

    states[stat].select { |key, value| return value if key == code }
  end

  def pluralize(n, singular, plural = nil)
    if n == 1
      singular
    elsif plural
      plural
    else
      "#{singular}s"
    end
  end

  def output_format(index, value)
    "Disk #{index}: #{value} #{pluralize(value, 'error')} detected"
  end

  def run
    begin
      manager = SNMP::Manager.new(
        host: config[:host].to_s,
        community: config[:community].to_s,
        version: config[:snmp_version].to_sym,
        timeout: config[:timeout].to_i
      )

      response = {}
      manager.walk([oid(config[:statistic]).to_s, oid(:pd_index)]) do |vb, index|
        response[index.value.to_i] = vb.value.to_i
        # puts "#{index.value}: #{vb.value}"
      end
    rescue SNMP::RequestTimeout
      unknown "Timeout: No Response from #{config[:host]}"
    rescue => e
      unknown "An unknown error occured: #{e.inspect}"
    end

    case config[:statistic]
    when 'pd_state'
      puts JSON.pretty_generate(response) if config[:debug]

      if config[:warning] || config[:critical]
        unknown 'This statistic does not take warning or critical values'
      else
        messages = []
        hot_spares = 0
        response.each do |index, value|
          case value
          when 24
            next
          when 2
            hot_spares += 1
            next
          else
            messages.push "Disk #{index}: #{state(:pd_state, value)}"
          end
        end

        ok "All disks optimal, #{hot_spares} Hot-spare" if messages.empty? && hot_spares >= 1
        warning 'All disks optimal, No hot-spares detected!' if messages.empty? && hot_spares < 1
        critical messages.join(', ')

      end
    when 'vd_state'
      puts JSON.pretty_generate(response) if config[:debug]

      unknown 'This statistic does not take warning or critical values' if config[:warning] || config[:critical]

      warnings = []
      criticals = []
      response.each do |index, value|
        next if value == 3
        warnings.push "Disk #{index}: #{state(:vd_state, value)}" if [2, 1].include? value
        criticals.push "Disk #{index}: #{state(:vd_state, value)}" if value == 0
      end

      puts warnings.inspect if config[:debug]
      puts criticals.inspect if config[:debug]

      ok 'All virtual devices optimal' if warnings.empty? && criticals.empty?
      warning warnings.join(', ') if warnings.count >= 1 && criticals.empty?
      critical (criticals + warnings).join(', ') if criticals.count >= 0
    when 'media_err_count', 'other_err_count', 'pred_fail_count'
      puts JSON.pretty_generate(response) if config[:debug]

      non_zeros = {}
      response.each do |index, value|
        next if value == 0
        non_zeros[index] = value
      end

      ok 'No errors detected' if non_zeros.empty?

      if config[:warning] || config[:critical]
        unknown 'Missing threshold range' if config[:warning].nil? || config[:critical].nil?

        w = config[:warning].to_i
        c = config[:critical].to_i

        warnings = []
        criticals = []
        non_zeros.each do |index, value|
          warnings.push output_format(index, value) if value >= w && value < c
          criticals.push output_format(index, value) if value >= c
        end
        warning warnings.join("\n") if warnings.count >= 1 && criticals.empty?
        critical (criticals + warnings).join("\n")
      else
        output = []
        non_zeros.each do |index, value|
          output.push output_format(index, value)
        end
        warning output.join("\n")
      end
    end

    manager.close
  end
end
