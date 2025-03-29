param(
    [string]$hostname,
    [int]$port,
    [string]$database,
    [string]$user
)

try {
    Get-Command psql.exe -ErrorAction Stop
}
catch {
    Write-Error "psql was not found. Please ensure PostgreSQL is installed and that psql is in your PATH."
    exit
}

$psqlCommand = "psql -U $user -h $hostname -p $port -d $database"

$sqlFiles = @(
    '01_database_schema.sql', 
    '02_database_trigger.sql', 
    '03_database_policy.sql', 
    '04_storage.sql', 
    '05_database_views.sql', 
    '99_database_schema_permission.sql'
)

foreach ($file in $sqlFiles) {
    try {
        Write-Host "Executing $file..."
        Invoke-Expression "$psqlCommand -f .\sql\$file"
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Potential issue with $file"
        }
    }
    catch {
        Write-Warning "Error in $file : $_"
    }
}