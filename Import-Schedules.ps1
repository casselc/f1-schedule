# Fetches and reformats all available F1 schedules from https://github.com/theOehrly/f1schedule

$seasons = @(2018..$(Get-Date).Year).ForEach({ $_.ToString() })
$schedule = [ordered] @{Seasons = $seasons }

foreach ($year in $seasons) {
  $data = $(Invoke-WebRequest -Uri "https://raw.githubusercontent.com/theOehrly/f1schedule/master/schedule_$year.json").Content | ConvertFrom-Json -AsHashtable
  $rounds = @($data['round_number'].GetEnumerator() | Sort-Object -Property Value | Select-Object -ExpandProperty Name)

  $events = $rounds.ForEach({ $data['event_name'][$_] })
  $season = [ordered] @{Events = $events }
  foreach ($round in $rounds) {
    $event_name = $data['event_name'][$round]
    $event_date = $data['event_date'][$round]
    $f1_event = [ordered] @{
      Date         = $event_date
      Round        = $data['round_number'][$round]
      OfficialName = $data['official_event_name'][$round]
      Location     = $data['location'][$round]
      Country      = $data['country'][$round]
      GmtOffset    = $data['gmt_offset'][$round]
      Format       = $data['event_format'][$round]
      Sessions     = 
      @($data['session1'][$round], 
        $data['session2'][$round], 
        $data['session3'][$round], 
        $data['session4'][$round], 
        $data['session5'][$round]).Where({ $PSItem })
    }
    foreach ($session in 1..5) {
      $session_name = $data["session$session"][$round]
      if (-not [string]::IsNullOrWhiteSpace($session_name)) {
        $session_date = $data["session$($session)_date"][$round]
        $f1_event[$data["session$session"][$round]] = [ordered] @{
          Date      = $session_date
          Session   = $session
          TimingUrl = "https://livetiming.formula1.com/static/$year/$($event_date.ToString('yyyy-MM-dd'))_$event_name/$($session_date.ToString('yyyy-MM-dd'))_$session_name/".Replace(' ', '_')
        }
      }
    }
    $season[$event_name] = $f1_event
  }
  $schedule[$year] = $season
}

$schedule | ConvertTo-Json -Depth 3 | Out-File -Encoding utf8NoBOM "f1_schedule.json"
$schedule | ConvertTo-Json -Depth 3 -Compress | Out-File -Encoding utf8NoBOM "f1_schedule.min.json"
$gzipped = [System.IO.Compression.GZipStream]::new(
  $(New-Item -ItemType File "f1_schedule.min.json.gz" -Force).OpenWrite(), 
  [System.IO.Compression.CompressionLevel]'SmallestSize')
$minified = (Get-Item "f1_schedule.min.json").OpenRead()

$minified.CopyTo($gzipped)
$gzipped.Close()
$minified.Close()