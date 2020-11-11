
# TODO load SQLServer module if it's not yet loaded
# TODO Test simple authentication in each function
# TODO Change $_.ToString() in catches to $_.Exception.ToString(), at least on smo 
# catches as smo apparently will not tell anything otherwise
# TODO Change $srv to $server, preferrably sooner rahter than later

function Test-SqlInstanceConnection
{
    # Returns $true if connection is successful
    Param(
        [Parameter(
            Mandatory=$true
        )]
        [String]$Name,
        [Parameter(
            ParameterSetName='IntegratedAuth',
            Mandatory=$true
        )]
        [Switch]$IntegratedAuthentication,
        [Parameter(
            ParameterSetName='SimpleAuth',
            Mandatory=$true
        )]
        [String]$UserName,
        [Parameter(
            ParameterSetName='SimpleAuth',
            Mandatory=$true
        )]
        [SecureString]$Password
    )
    try
    {
        if ($IntegratedAuthentication.IsPresent) {
            $connString = "Data Source=$Name;Integrated Security=True"
        } elseif ($Username -and $Password){
            $connString = "Data Source=$Name;User ID=$UserName;Password=" + `
                ($Password | ConvertFrom-SecureString -AsPlainText)
        }

        $conn = New-Object System.Data.SqlClient.SqlConnection $connString
        $conn.Open()
        if ($conn.State -eq "Open")
        {
            $conn.Close()
            return $true
        }
        return $false
    }
    catch
    {
        throw "Error connecting to $($Instance): $($_.ToString())"
    }
}

# TODO
# function Test-SqlDatabaseConnection
# {
# }
# It's looking like it might make sense to just test connection to an 
# instance and then list db's from said instance and see if the database
# you're looking for is returned. Or something along those lines.

function Get-SqlColumnType
{
    Param(
        [Parameter(Mandatory=$true)][String]$ColumnType
    )
    if ($ColumnType -match 'NChar\(\d*?\)') {
        [Int]$i = ($ColumnType | Select-String -Pattern '\(\d*' ).Matches.Value -replace '\('
        $cType = [Microsoft.SqlServer.Management.Smo.DataType]::NChar($i)
    }

    if (-not $cType) {
        throw "Column type $ColumnType not recognized"
    }

    return $cType
}

function New-SqlDatabase
{
    # NOTE Not sure yet what to ultimately return here so let's go with the DB for now
    # NOTE Also not sure what to go with if the DB exists already so let's throw an error
    Param(
        [Parameter(
            Mandatory=$true,
            Position=0,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$Instance,
        [Parameter(
            Mandatory=$true,
            Position=1,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$Database,
        [Parameter(
            ParameterSetName='IntegratedAuth',
            Mandatory=$false,
            Position=2,
            ValueFromPipelineByPropertyName=$true
        )]
        [Switch]$IntegratedAuthentication,
        [Parameter(
            ParameterSetName='SimpleAuth',
            Mandatory=$false,
            Position=2,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$UserName,
        [Parameter(
            ParameterSetName='SimpleAuth',
            Mandatory=$false,
            Position=3,
            ValueFromPipelineByPropertyName=$true
        )]
        [SecureString]$Password
    )
    Process {
        try
        {
            if ($IntegratedAuthentication.IsPresent) {
                $srv = New-Object Microsoft.SqlServer.Management.Smo.Server($Instance)
                $srv.ConnectionContext.LoginSecure = $true
            } elseif ($Username -and $Password){
                $srv = New-Object Microsoft.SqlServer.Management.Smo.Server($Instance)
                $srv.ConnectionContext.LoginSecure = $false
                $srv.ConnectionContext.Login = $UserName
                $srv.ConnectionContext.Password = ($Password | ConvertFrom-SecureString -AsPlainText)
            }
        }
        catch
        {
            throw "Error connecting to $($Instance): $($_.ToString())"
        }

        try
        {
            if ($null -eq $srv.Databases[$Database]) {
                $db = New-Object Microsoft.SqlServer.Management.Smo.Database($srv, $Database)
                $db.Create()
                return $db
            } else {
                throw "Database $Instance\$($Database) already exists"
            }
        }
        catch
        {
            throw "Error creating database $Instance\$($Database): $($_.ToString())"
        }
    }
}

function New-SqlTable
{
    # TODO Write something here
    # TODO Actually add proper help text
    Param(
        [Parameter(
            Mandatory=$true,
            Position=0,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$InstanceName,
        [Parameter(
            Mandatory=$true,
            Position=1,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$DatabaseName,
        [Parameter(
            Mandatory=$true,
            Position=2,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$TableName,
        [Parameter(
            Mandatory=$true,
            Position=2,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$ColumnName, 
        [Parameter(
            Mandatory=$true,
            Position=2,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$ColumnType, # Such as NChar(50)
        [Parameter(
            ParameterSetName='IntegratedAuth',
            Mandatory=$false,
            Position=3,
            ValueFromPipelineByPropertyName=$true
        )]
        [Switch]$IntegratedAuthentication,
        [Parameter(
            ParameterSetName='SimpleAuth',
            Mandatory=$false,
            Position=3,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$UserName,
        [Parameter(
            ParameterSetName='SimpleAuth',
            Mandatory=$false,
            Position=4,
            ValueFromPipelineByPropertyName=$true
        )]
        [SecureString]$Password
    )
    Begin {
        $cType = Get-SqlColumnType -ColumnType $ColumnType
    } Process {
        try
        {
            if ($IntegratedAuthentication.IsPresent) {
                $srv = New-Object Microsoft.SqlServer.Management.Smo.Server($Instance)
                $srv.ConnectionContext.LoginSecure = $true
            } elseif ($Username -and $Password){
                $srv = New-Object Microsoft.SqlServer.Management.Smo.Server($Instance)
                $srv.ConnectionContext.LoginSecure = $false
                $srv.ConnectionContext.Login = $UserName
                $srv.ConnectionContext.Password = ($Password | ConvertFrom-SecureString -AsPlainText)
            }
        }
        catch
        {
            throw "Error connecting to $($Instance): $($_.ToString())"
        }

        try
        {
            if ($null -ne $srv.Databases[$DatabaseName]) {
                # TODO Create (and return?) table
                # TODO Also check if the column already exists
                $database = $srv.Databases[$DatabaseName]
                $table = New-Object Microsoft.SqlServer.Management.Smo.Table($database, $TableName)
                $column = New-Object Microsoft.SqlServer.Management.Smo.Column($table, $ColumnName, $cType)
                $table.Columns.Add($column)
                $table.Create()
            } else {
                throw "Unable to create table $InstanceName\$DatabaseName\$TableName, " + `
                    "database $DatabaseName does not exist"
            }
        }
        catch
        {
            throw "Error creating database $InstanceName\$($DatabaseName): $($_.Exception.ToString())"
        }
    }
}

function New-SqlColumn
{
    # TODO Write something here
    # TODO Actually add propers help text
    # TODO Use *Name in parameter names across all functions
    Param(
        [Parameter(
            Mandatory=$true,
            Position=0,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$InstanceName,
        [Parameter(
            Mandatory=$true,
            Position=1,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$DatabaseName,
        [Parameter(
            Mandatory=$true,
            Position=2,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$TableName,
        [Parameter(
            Mandatory=$true,
            Position=2,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$ColumnName, 
        [Parameter(
            Mandatory=$true,
            Position=2,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$ColumnType, # Such as NChar(50)
        [Parameter(
            ParameterSetName='IntegratedAuth',
            Mandatory=$false,
            Position=3,
            ValueFromPipelineByPropertyName=$true
        )]
        [Switch]$IntegratedAuthentication,
        [Parameter(
            ParameterSetName='SimpleAuth',
            Mandatory=$false,
            Position=3,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$UserName,
        [Parameter(
            ParameterSetName='SimpleAuth',
            Mandatory=$false,
            Position=4,
            ValueFromPipelineByPropertyName=$true
        )]
        [SecureString]$Password
    )
    Begin {
        $cType = Get-SqlColumnType -ColumnType $ColumnType
    } Process {
        try
        {
            if ($IntegratedAuthentication.IsPresent) {
                $srv = New-Object Microsoft.SqlServer.Management.Smo.Server($InstanceName)
                $srv.ConnectionContext.LoginSecure = $true
            } elseif ($Username -and $Password){
                $srv = New-Object Microsoft.SqlServer.Management.Smo.Server($InstanceName)
                $srv.ConnectionContext.LoginSecure = $false
                $srv.ConnectionContext.Login = $UserName
                $srv.ConnectionContext.Password = ($Password | ConvertFrom-SecureString -AsPlainText)
            }
        }
        catch
        {
            throw "Error connecting to $($Instance): $($_.ToString())"
        }

        try
        {
            if ($null -ne $srv.Databases[$DatabaseName]) {
                # TODO Also check if the table exists
                # TODO Also check if the column already exists
                $table = $srv.Databases[$DatabaseName].Tables[$TableName]
                $column = New-Object Microsoft.SqlServer.Management.Smo.Column($table, $ColumnName, $cType)
                $table.Columns.Add($column)
                $table.Alter()
            } else {
                throw "Unable to add column $ColumnName to $InstanceName\$DatabaseName\$TableName, " + `
                    "database $DatabaseName does not exist"
            }
        }
        catch
        {
            throw "Error creating database $InstanceName\$($DatabaseName): $($_.ToString())"
        }
    }
}

function Get-SqlInstanceConnection
{
    # Returns a connection to a database
    Param(
        [Parameter(
            Mandatory=$true,
            Position=0,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$Instance,
        [Parameter(
            ParameterSetName='IntegratedAuth',
            Mandatory=$false,
            Position=1,
            ValueFromPipelineByPropertyName=$true
        )]
        [Switch]$IntegratedAuthentication,
        [Parameter(
            ParameterSetName='SimpleAuth',
            Mandatory=$false,
            Position=1,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$UserName,
        [Parameter(
            ParameterSetName='SimpleAuth',
            Mandatory=$false,
            Position=2,
            ValueFromPipelineByPropertyName=$true
        )]
        [SecureString]$Password
    )
    Process {
        try
        {
            if ($IntegratedAuthentication.IsPresent) {
                $connString = "Data Source=$Instance;Integrated Security=True"
            } elseif ($Username -and $Password){
                $connString = "Data Source=$Instance;User ID=$UserName;Password=" + `
                    ($Password | ConvertFrom-SecureString -AsPlainText)
            }

            return New-Object System.Data.SqlClient.SqlConnection $connString
        }
        catch
        {
            throw "Error connecting to $($Instance): $($_.ToString())"
        }
    }
}

