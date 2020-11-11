
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
            if ($null -eq $srv.Databases[$Instance]) {
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


