# Required gems for the base bot
# NOTE: Ensure the bundler gem is installed!
require 'bundler/setup'
require 'discordrb'
require 'yaml'

# The main bot
# All individual crystals will be submodules of this; this gives them access to the main 
# bot object through a constant, as well as a global rate limiter and data folder path constant
module Bot
  # Loads bot configuration from file
  config = OpenStruct.new(YAML.load(File.open('../config.yml')))

  # Raises a RuntimeError for any missing required components and exits
  if config.id.nil?
    raise 'Client ID not found!'
  end
  if config.token.nil?
    raise 'Token not found!'
  end
  if config.prefix.nil?
    raise 'Command prefix not found!'
  end
  if config.id.nil? || config.token.nil? || config.prefix.nil?
    exit(false)
  end

  # Loads files from lib directory in parent
  Dir['../lib/*.rb'].each { |l| puts l }

  # Creates the bot object. This is a constant in order to make it usable by crystals
  BOT = Discordrb::Commands::CommandBot.new(
    client_id:    config.id,
    token:        config.token,
    prefix:       config.prefix,
    help_command: config.help_alias ? config.help_alias.to_sym : nil,
    channels:     config.channel_whitelist ? config.channel_whitelist.split(',').map { |id| id.to_i } : nil,
    parse_self:   config.react_to_self ? true : false,
    ignore_bots:  !config.react_to_bots ? true : false
  )

  # Sets bot's playing game
  BOT.ready { BOT.game = config.game.to_s }

  # Rate limiter object for use in all crystals
  RATE_LIMITER = Discordrb::Commands::SimpleRateLimiter.new

  # Full path string for the crystal data folder (data in parent)
  DATA_PATH = File.expand_path('../data')

  # Loads a crystal from the given file and includes the module into the bot's container.
  # 
  # @param file [File] the file to load the crystal from. Filename must be the crystal 
  #   name in snake case, or this will not work! (The crystal template generator 
  #   will do this automatically.)
  def self.load_crystal(file)
    module_name = File.basename(file.path, '.*').split('_').map(&:capitalize).join
    load file
    BOT.include! self.const_get(module_name)
  end

  # Loads crystals depending on command line flags. Usage as follows:
  # --main, -m: Loads all crystals in crystals/main; default with no arguments
  # --development, -d: Loads all crystals in crystals/dev
  # --all, -a: Loads all crystals from both crystals/main and crystals/dev
  # NOTE: Multiple flags are not supported (or needed); only the first argument is read.
  if !ARGV[0] || %w(--main -m --all -a).include?(ARGV[0])
    Dir['crystals/main/*.rb'].each do |file|
      load_crystal(file)
    end
  end
  if %w(--development -d --all -a).include?(ARGV[0])
    Dir['crystals/dev/*.rb'].each do |file|
      load_crystal(file)
    end
  end

  # After loading all desired crystals, runs the bot
  BOT.run
end