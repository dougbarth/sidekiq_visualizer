# sidekiq_visualizer

Tools for visualizing Sidekiq activity from logs. This version currently processes Papertrail JSON output. This could be improved by separating parsing from processing.

## Steps to use

Download logs locally using the papertrail CLI. Use the JSON format

```
papertrail --json '"TID-"'  > output.json
```

Send those logs through viz.rb and save the HTML to a file.

```
ruby viz.rb output.json > output.html
```

If you want to filter jobs, you can use a pipeline

```
grep MyJob output.json | ruby viz.rb > output.html
```
