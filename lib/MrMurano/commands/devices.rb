# Last Modified: 2017.08.16 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/Gateway'

command 'device' do |c|
  c.syntax = %(murano device)
  c.summary = %(Interact with a device)
  c.description = %(
Interact with a device.
  ).strip
  c.project_not_required = true

  c.action do |_args, _options|
    ::Commander::UI.enable_paging
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'device list' do |c|
  c.syntax = %(murano device list [--options])
  c.summary = %(List identifiers for a product)
  c.description = %(
List identifiers for a product.
  ).strip

  c.option '--limit NUMBER', Integer, %(How many devices to return)
  c.option '--before TIMESTAMP', Integer, %(Show devices before timestamp)
  c.option '-l', '--long', %(show everything)
  c.option '-o', '--output FILE', %(Download to file instead of STDOUT)

  c.action do |args, options|
    #options.default :limit=>1000

    prd = MrMurano::Gateway::Device.new
    MrMurano::Verbose.whirly_start 'Looking for devices...'
    data = prd.list(options.limit, options.before)
    MrMurano::Verbose.whirly_stop
    exit 1 if data.nil?

    if !data[:devices].empty?
      io = File.open(options.output, 'w') if options.output
      prd.outf(data, io) do |_dd, ios|
        dt = {}
        if options.long
          dt[:headers] = [
            :Identifier,
            :AuthType,
            :Locked,
            :Reprovision,
            'Dev Mode',
            'Last IP',
            'Last Seen',
            :Status,
            :Online,
          ]
          dt[:rows] = data[:devices].map do |row|
            [
              row[:identity],
              (row[:auth] || {})[:type],
              row[:locked],
              row[:reprovision],
              row[:devmode],
              row[:lastip],
              row[:lastseen],
              row[:status],
              row[:online],
            ]
          end
        else
          dt[:headers] = %i[Identifier Status Online]
          dt[:rows] = data[:devices].map do |row|
            [row[:identity], row[:status], row[:online]]
          end
        end
        prd.tabularize(dt, ios)
      end
      io.close unless io.nil?
    else
      prd.warning 'Did not find any devices'
    end
  end
end
alias_command 'devices list', 'device list'

command 'device read' do |c|
  c.syntax = %(murano device read <identifier> (<alias>...))
  c.summary = %(Read state of a device)
  c.description = %(
Read state of a device.

This reads the latest state values for the resources in a device.
  ).strip

  c.option '-o', '--output FILE', %(Download to file instead of STDOUT)

  c.action do |args, options|
    prd = MrMurano::Gateway::Device.new
    if args.count < 1 then
      prd.error "Identifier missing"
      exit 1
    end
    snid = args.shift

    # FIXME/2017-06-14: Confirm that whirly is helpful here.
    MrMurano::Verbose.whirly_start 'Fetching device data...'
    data = prd.read(snid)
    MrMurano::Verbose.whirly_stop
    exit 1 if data.nil?

    io = File.open(options.output, 'w') if options.output
    data.select! { |k, _v| args.include? k.to_s } unless args.empty?
    prd.outf(data, io) do |dd, ios|
      rows = []
      dd.each_pair do |k, v|
        rows << [k, v[:reported], v[:set], v[:timestamp]]
      end
      prd.tabularize(
        {
          headers: %i[Alias Reported Set Timestamp],
          rows: rows,
        },
        ios
      )
    end
    io.close unless io.nil?
  end
end

command 'device write' do |c|
  c.syntax = %(murano device write <identifier> <Alias=Value> [<Alias=Value>...])
  c.summary = %(Write to 'set' of aliases on devices)
  c.description = %(
Write to 'set' of aliases on devices.

If an alias is not settable, this will fail.
  ).strip


  c.action do |args, options|
    resources = (MrMurano::Gateway::GweBase.new.info or {})[:resources]
    prd = MrMurano::Gateway::Device.new
    if args.count < 1 then
      prd.error "Identifier missing"
      exit 1
    end
    snid = args.shift

    set = Hash[args.map { |i| i.split('=') }]
    set.each_pair do |k, v|
      fmt = ((resources[k.to_sym] || {})[:format] || 'string')
      case fmt
      when 'number'
        if v.to_f.to_i == v.to_i
          set[k] = v.to_i
        else
          set[k] = v.to_f
        end
      when 'string'
        set[k] = '' if v.nil?
      when 'boolean'
        set[k] = %w[1 yes true on].include?(v.downcase)
      end
    end

    ret = prd.write(snid, set)
    # On success, write returns empty curlies {}. So check nil or empty.
    prd.outf(ret) unless ret.nil? || ret.empty?
  end
end

command 'device enable' do |c|
  c.syntax = %(murano device enable [<identifier>|--file <identifiers>])
  c.summary = %(Enable an Identifier; Creates device in Murano)
  c.description = %(
Enables Identifiers, creating the digial shadow in Murano.
  ).strip

  c.option '-f', '--file FILE', %(A file of serial numbers, one per line)
  c.option '--key FILE', %(Public TLS key for this device)

  c.action do |args, options|
    # SKIP: c.verify_arg_count!(args)
    prd = MrMurano::Gateway::Device.new
    if !options.file.nil? && !options.key.nil?
      prd.error %(Cannot use both --file and --key)
      exit 1
    end
    if options.file
      # Check file for headers.
      header = File.new(options.file).gets
      if header.nil?
        prd.error 'Nothing in file!'
        exit 1
      end
      unless header =~ /\s*ID\s*(,SSL Client Certificate\s*)?/
        prd.error "Missing column headers in file \"#{options.file}\""
        prd.error %(First line in file should be either "ID" or "ID, SSL Client Certificate")
        exit 2
      end
      prd.enable_batch(options.file)
    elsif args.count > 0
      if options.key
        File.open(options.key, 'rb') do |io|
          prd.enable(args[0], type: :certificate, publickey: io)
        end
      else
        prd.enable(args[0])
      end
    else
      prd.error 'Missing an Identifier to enable'
    end
  end
end

command 'device activate' do |c|
  c.syntax = %(murano device activate <identifier>)
  c.summary = %(Activate a serial number, retriving its CIK)
  c.description = %(
Activate an Identifier.

Generally you should not use this.

Instead, the device should make the activation call itself
and save the CIK token.

But sometimes when building a proof-of-concept it is just
easier to hardcode the CIK.

Note that you can only activate a device once. After that
you cannot retrive the CIK again.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args, nil, ['Identifier missing'])
    prd = MrMurano::Gateway::Device.new
    prd.outf prd.activate(args.first)
  end
end

command 'device delete' do |c|
  c.syntax = %(murano device delete <identifier>)
  c.summary = %(Delete a device)
  c.description = %(
Delete a device.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args, nil, ['Identifier missing'])
    prd = MrMurano::Gateway::Device.new
    snid = args.shift
    ret = prd.remove(snid)
    prd.outf ret unless ret.empty?
  end
end

command 'device httpurl' do |c|
  c.syntax = %(murano device httpurl)
  c.summary = %(Get the URL for the HTTP-Data-API for this Project)
  c.description = %(
Get the URL for the HTTP-Data-API for this Project.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args)
    prd = MrMurano::Gateway::GweBase.new
    ret = prd.info
    say "https://#{ret[:fqdn]}/onep:v1/stack/alias"
  end
end

alias_command 'product device', 'device'
alias_command 'product device list', 'device list'
alias_command 'product devices list', 'device list'
alias_command 'product device read', 'device read'
alias_command 'product device twee', 'device read'
alias_command 'product device write', 'device write'
alias_command 'product device enable', 'device enable'
alias_command 'product device activate', 'device activate'
alias_command 'product device delete', 'device delete'
alias_command 'product device httpurl', 'device httpurl'

