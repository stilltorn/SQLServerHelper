
# TODO Test simple authentication in each function
# TODO Function/parameter help texts

if (-not (Get-Module -Name SQLServer)) {
    try {
        Import-Module -Name SQLServer -ErrorAction Stop
    } catch {
        throw "Unable to import SQLServer module: $($_.ToString())"
    }
}

function Test-SqlInstanceConnection
{
    # Returns $true if connection is successful
    Param(
        [Parameter(
            Mandatory=$true
        )]
        [String]$InstanceName,
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
            $connString = "Data Source=$InstanceName;Integrated Security=True"
        } elseif ($Username -and $Password){
            $connString = "Data Source=$InstanceName;User ID=$UserName;Password=" + `
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

function Get-SqlColumnType
{
    Param(
        [Parameter(Mandatory=$true)][String]$ColumnType
    )
    # NOTE I could not for the life of me figure out a better 
    # way of declaring the type from a string variable
    if ($ColumnType -match 'NChar\(\d*?\)') {
        [Int]$i = ($ColumnType | Select-String -Pattern '\(\d*' ).Matches.Value -replace '\('
        $cType = [Microsoft.SqlServer.Management.Smo.DataType]::NChar($i)
    }

    $typeMap = @{
         TinyInt = [Microsoft.SqlServer.Management.Smo.DataType]::TinyInt
        SmallInt = [Microsoft.SqlServer.Management.Smo.DataType]::SmallInt
             Int = [Microsoft.SqlServer.Management.Smo.DataType]::Int
          BigInt = [Microsoft.SqlServer.Management.Smo.DataType]::BigInt
            Real = [Microsoft.SqlServer.Management.Smo.DataType]::Real
        DateTime = [Microsoft.SqlServer.Management.Smo.DataType]::DateTime
    }

    if (-not $cType) {
        $cType = $typeMap.$ColumnType
        if (-not $cType) {
            throw "Column type $ColumnType not recognized"
        }
    }

    return $cType
}

function Get-SqlDatabase
{
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
                $server = New-Object Microsoft.SqlServer.Management.Smo.Server($InstanceName)
                $server.ConnectionContext.LoginSecure = $true
            } elseif ($Username -and $Password){
                $server = New-Object Microsoft.SqlServer.Management.Smo.Server($InstanceName)
                $server.ConnectionContext.LoginSecure = $false
                $server.ConnectionContext.Login = $UserName
                $server.ConnectionContext.Password = ($Password | ConvertFrom-SecureString -AsPlainText)
            }
        }
        catch
        {
            throw "Error connecting to $($InstanceName): $($_.Exception.ToString())"
        }

        try
        {
            return $server.Databases[$DatabaseName]
        }
        catch
        {
            throw "Error creating database $InstanceName\$($DatabaseName): $($_.Exception.ToString())"
        }
    }
}

function New-SqlDatabase
{
    # Creates a new database and returns it
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
                $server = New-Object Microsoft.SqlServer.Management.Smo.Server($InstanceName)
                $server.ConnectionContext.LoginSecure = $true
            } elseif ($Username -and $Password){
                $server = New-Object Microsoft.SqlServer.Management.Smo.Server($InstanceName)
                $server.ConnectionContext.LoginSecure = $false
                $server.ConnectionContext.Login = $UserName
                $server.ConnectionContext.Password = ($Password | ConvertFrom-SecureString -AsPlainText)
            }
        }
        catch
        {
            throw "Error connecting to $($InstanceName): $($_.Exception.ToString())"
        }

        try
        {
            if ($null -eq $server.Databases[$DatabaseName]) {
                $dataBase = New-Object Microsoft.SqlServer.Management.Smo.Database($server, $DatabaseName)
                $dataBase.Create()
                return $dataBase
            } else {
                throw "Database $InstanceName\$($DatabaseName) already exists"
            }
        }
        catch
        {
            throw "Error creating database $InstanceName\$($DatabaseName): $($_.Exception.ToString())"
        }
    }
}

function New-SqlTable
{
    # Creates a new table with one minimum column required by SQL, 
    # use Add-SqlColumn to add more columns
    Param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$InstanceName,
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$DatabaseName,
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$TableName,
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$ColumnName, 
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$ColumnType,
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [Switch]$SetColumnAsIdentity,
        [Parameter(
            ParameterSetName='IntegratedAuth',
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [Switch]$IntegratedAuthentication,
        [Parameter(
            ParameterSetName='SimpleAuth',
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$UserName,
        [Parameter(
            ParameterSetName='SimpleAuth',
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [SecureString]$Password
    )
    Process {
        $cType = Get-SqlColumnType -ColumnType $ColumnType
        try
        {
            if ($IntegratedAuthentication.IsPresent) {
                $server = New-Object Microsoft.SqlServer.Management.Smo.Server($InstanceName)
                $server.ConnectionContext.LoginSecure = $true
            } elseif ($Username -and $Password) {
                $server = New-Object Microsoft.SqlServer.Management.Smo.Server($InstanceName)
                $server.ConnectionContext.LoginSecure = $false
                $server.ConnectionContext.Login = $UserName
                $server.ConnectionContext.Password = ($Password | ConvertFrom-SecureString -AsPlainText)
            }
        }
        catch
        {
            throw "Error connecting to $($InstanceName): $($_.Exception.ToString())"
        }
        try
        {
            $database = $server.Databases[$DatabaseName]
            $table = New-Object Microsoft.SqlServer.Management.Smo.Table($database, $TableName)
            $column = New-Object Microsoft.SqlServer.Management.Smo.Column($table, $ColumnName, $cType)
            if ($SetColumnAsIdentity.IsPresent -and $ColumnType -match 'Int') {
                $column.Identity = $true
                $column.IdentitySeed = 1
                $column.IdentityIncrement = 1
            } elseif ($SetColumnAsIdentity.IsPresent) {
                throw "Only integer types supported as the identity column for now"
            }
            $table.Columns.Add($column)
            $table.Create()
            return $table
        }
        catch
        {
            throw "Error creating table $TableName in $InstanceName\$($DatabaseName): " + `
                "$($_.Exception.ToString())"
        }
    }
}

function Add-SqlColumn
{
    # Adds a column to a table and returns said table
    Param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$InstanceName,
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$DatabaseName,
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$TableName,
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$ColumnName, 
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$ColumnType,
        [Parameter(
            Mandatory=$false,
            ValueFromPipelineByPropertyName=$true
        )]
        [Switch]$SetColumnAsIdentity,
        [Parameter(
            ParameterSetName='IntegratedAuth',
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [Switch]$IntegratedAuthentication,
        [Parameter(
            ParameterSetName='SimpleAuth',
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$UserName,
        [Parameter(
            ParameterSetName='SimpleAuth',
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [SecureString]$Password
    )
    Process {
        $cType = Get-SqlColumnType -ColumnType $ColumnType
        try
        {
            if ($IntegratedAuthentication.IsPresent) {
                $server = New-Object Microsoft.SqlServer.Management.Smo.Server($InstanceName)
                $server.ConnectionContext.LoginSecure = $true
            } elseif ($Username -and $Password){
                $server = New-Object Microsoft.SqlServer.Management.Smo.Server($InstanceName)
                $server.ConnectionContext.LoginSecure = $false
                $server.ConnectionContext.Login = $UserName
                $server.ConnectionContext.Password = ($Password | ConvertFrom-SecureString -AsPlainText)
            }
        }
        catch
        {
            throw "Error connecting to $($Instance): $($_.Exception.ToString())"
        }
        try
        {
            $table = $server.Databases[$DatabaseName].Tables[$TableName]
            $column = New-Object Microsoft.SqlServer.Management.Smo.Column($table, $ColumnName, $cType)
            if ($SetColumnAsIdentity.IsPresent -and $ColumnType -match 'Int') {
                $column.Identity = $true
                $column.IdentitySeed = 1
                $column.IdentityIncrement = 1
            } elseif ($SetColumnAsIdentity.IsPresent) {
                throw "Only integer types supported as the identity column for now"
            }
            $table.Columns.Add($column)
            $table.Alter()
            return $table
        }
        catch
        {
            throw "Error adding column $ColumnName to database $InstanceName\$DatabaseName " + `
                "table $($TableName): $($_.Exception.ToString())"
        }
    }
}

function Remove-SqlObject
{
    Param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$InstanceName,
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$DatabaseName,
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$ObjectName,
        [Parameter(
            Mandatory=$false,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$ColumnName,
        [Parameter(
            Mandatory=$false,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$RowNumber, # TODO Not sure what to use here yet
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [ValidateSet('Database','Table','Column','Row')]
        [String]$ObjectType,
        [Parameter(
            ParameterSetName='IntegratedAuth',
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [Switch]$IntegratedAuthentication,
        [Parameter(
            ParameterSetName='SimpleAuth',
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$UserName,
        [Parameter(
            ParameterSetName='SimpleAuth',
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [SecureString]$Password
    )
    Process {
        try
        {
            if ($IntegratedAuthentication.IsPresent) {
                $server = New-Object Microsoft.SqlServer.Management.Smo.Server($InstanceName)
                $server.ConnectionContext.LoginSecure = $true
            } elseif ($Username -and $Password){
                $server = New-Object Microsoft.SqlServer.Management.Smo.Server($InstanceName)
                $server.ConnectionContext.LoginSecure = $false
                $server.ConnectionContext.Login = $UserName
                $server.ConnectionContext.Password = ($Password | ConvertFrom-SecureString -AsPlainText)
            }
        }
        catch
        {
            throw "Error connecting to $($Instance): $($_.Exception.ToString())"
        }
        try
        {
            switch ($ObjectType) {
                'Database' { throw "Database destuction not yet implemented" }
                   'Table' {
                                $table = $server.Databases[$DatabaseName].Tables[$ObjectName]
                                $table.Drop()
                           }
                  'Column' { throw "Column destuction not yet implemented"  }
                     'Row' { throw "Row destuction not yet implemented" }
            }
        }
        catch
        {
            throw "Error removing $ObjectType $ObjectName from database $InstanceName\$($DatabaseName): " + `
                "$($_.Exception.ToString())"
        }
    }
}

