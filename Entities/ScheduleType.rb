class ScheduleTypes < Entities
  def setup_data
    value_str :name
    value_str :schedule
  end

  def self.get_script
    return IO.read('Files/timetable.js')
  end

  def self.get_html(weeks: false)
    return "<style type='text/css'>
        td.select {
            background-color: #00ffff
        }</style>
    <table width='80%' border=0 onload='add_weeks(16); add_days();add_hours();'> " +
        (weeks ? "<tr id='tr_weeks'></tr>" : '') +
        "<tr id='tr_days'></tr>
      <tr id='tr_programs'></ tr>
    <tr id='tr_hours'></tr>
    </ table>"
  end
end

class ScheduleType < Entity
  def schedule_array
    JSON.parse(schedule)
  end

  def schedule_array=(s)
    schedule = s.to_json
  end
end