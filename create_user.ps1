$body = @{
    "email" = "admin@krishirakshak.com"
    "password" = "krishi123"
} | ConvertTo-Json

$headers = @{
    "apikey" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuYnJ3Ymlidmxienp6dGVuZnpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjYzNjY0NCwiZXhwIjoyMDg4MjEyNjQ0fQ.YOwlm4NOakmQxChSHQ2D-364zhg0FncfVF9-ReZOuck"
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-RestMethod -Uri "https://cnbrwbibvlbzzztenfzr.supabase.co/auth/v1/signup" -Headers $headers -Method Post -Body $body
    Write-Host "Success: $($response | ConvertTo-Json -Depth 5)"
} catch {
    Write-Host "Error: $($_.Exception.Message)"
    $stream = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $responseBody = $reader.ReadToEnd()
    Write-Host "Response: $responseBody"
}