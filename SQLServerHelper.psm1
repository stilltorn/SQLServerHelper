
function Test-SqlConnection
{
    # Returns $true if connection is successful
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
                $connString = "Data Source=$Instance;Database=$Database;Integrated Security=True"
            } elseif ($Username -and $Password){
                $connString = "Data Source=$Instance;Database=$Database;User ID=$UserName;Password=" + `
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
            throw "Error connecting to $Instance\$($Database): $($_)"
        }
    }
}

