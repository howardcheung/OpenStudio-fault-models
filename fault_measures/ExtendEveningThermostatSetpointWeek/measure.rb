# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

require 'date'
require_relative 'resources/global_const'
require_relative 'resources/misc_arguments'
require_relative 'resources/misc_run_week_exteveninghr'

# start the measure
class ExtendEveningThermostatSetpointWeek < OpenStudio::Ruleset::ModelUserScript
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'ExtendEveningThermostatSetpointWeek'
  end

  # simple human readable description
  def description
    return 'This Measure simulates the effect of having a daytime ' \
      'thermostat schedule extended to the evening because of '\
      'programming mistake.'
  end

  # detailed human readable description about how to use the measure
  def modeler_description
    return 'To use this Measure, choose the Zone that is faulted, ' \
      'and the period of time what you want the fault to occur. ' \
      'You should also enter the number of hours that the extension ' \
      'sustains. The measure will detect the thermostat schedule of the ' \
      'automatically, and adjust the evening schedule to the daytime ' \
      'schedule. Note that this measure only works for buildings close ' \
      'before midnight. You also need to choose one day in a week (Monday, ' \
      'Tuesday, .....) to simulate weekly fault occurence.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # make choice argument for thermal zone
    zone_handles, zone_display_names = pass_zone(model, $allzonechoices)
    zone = OpenStudio::Ruleset::OSArgument.makeChoiceArgument(
      'zone', zone_display_names, zone_display_names, true
    )
    zone.setDefaultValue(zone_display_names[0])
    zone.setDisplayName('Zone')
    args << zone

    osmonths = OpenStudio::StringVector.new
    $months.each do |month|
      osmonths << month
    end

    start_month = OpenStudio::Ruleset::OSArgument.makeChoiceArgument(
      'start_month', osmonths, true
    )
    start_month.setDisplayName('Fault active start month')
    start_month.setDefaultValue($months[0])
    args << start_month

    end_month = OpenStudio::Ruleset::OSArgument.makeChoiceArgument(
      'end_month', osmonths, true
    )
    end_month.setDisplayName('Fault active end month')
    end_month.setDefaultValue($months[11])
    args << end_month

    osdaysofweeks = OpenStudio::StringVector.new
    $dayofweeks.each do |day|
      osdaysofweeks << day
    end
    osdaysofweeks << $all_days
    osdaysofweeks << $weekdaysonly
    osdaysofweeks << $weekendonly
    dayofweek = OpenStudio::Ruleset::OSArgument.makeChoiceArgument(
      'dayofweek', osdaysofweeks, true
    )
    dayofweek.setDisplayName('Day of the week')
    dayofweek.setDefaultValue($all_days)
    args << dayofweek

    ext_hr = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('ext_hr', true)
    ext_hr.setDisplayName(
      'Number of operating hours extended to the evening.'
    )
    ext_hr.setDefaultValue(1)  # default leakage level to be 1 hour
    args << ext_hr

    return args
    # note: the Assignment Branch Condition size is left higher than the
    # recommended minimum by Rubocop because the argument definition
    # functions are left in measure.rb to create json files automatically
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    unless runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # get inputs
    ext_hr = runner.getDoubleArgumentValue('ext_hr', user_arguments)
    if ext_hr != 0
      start_month, end_month, thermalzones, dayofweek = \
        getinputs(model, runner, user_arguments)

      # apply fault
      thermalzones.each do |thermalzone|
        applyfaulttothermalzone(
          thermalzone, ext_hr, start_month, end_month, dayofweek, runner
        )
      end
    else
      runner.registerAsNotApplicable('Zero hour extension in Measure ' \
                                     'ExtendEveningThermostatSetpointWeek. ' \
                                     'Exiting......')
    end

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ExtendEveningThermostatSetpointWeek.new.registerWithApplication
