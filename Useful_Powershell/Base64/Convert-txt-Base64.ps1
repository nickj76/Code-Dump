$MYTEXT = '<?xml version="1.0" encoding="utf-8" standalone="yes"?>

<Activation>

  <Request>

    <FirstName>Ron</FirstName>

    <LastName>Marsh</LastName>

    <Email>r.a.marsh@surrey.ac.uk</Email>

    <Phone>+1-555-555-5555</Phone>

    <Fax>+1-555-555-5555</Fax>

    <JobTitle>Your Job Title</JobTitle>

    <Industry>Your Industry</Industry>

    <Department>Your Department</Department>

    <Organization>University of Surrey</Organization>

    <AddressLine1>Stag Hill Campus</AddressLine1>

    <AddressLine2>Austin Pearce Building</AddressLine2>

    <City>Guildford</City>

    <Zipcode>GU27XH</Zipcode>

    <Country>UK</Country>

    <State>Surrey</State>

  </Request>

</Activation>'
$ENCODED = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($MYTEXT))
Write-Output $ENCODED