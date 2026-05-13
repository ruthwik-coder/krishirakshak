$headers = @{
    "apikey" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuYnJ3Ymlidmxienp6dGVuZnpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjYzNjY0NCwiZXhwIjoyMDg4MjEyNjQ0fQ.YOwlm4NOakmQxChSHQ2D-364zhg0FncfVF9-ReZOuck"
    "Authorization" = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuYnJ3Ymlidmxienp6dGVuZnpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjYzNjY0NCwiZXhwIjoyMDg4MjEyNjQ0fQ.YOwlm4NOakmQxChSHQ2D-364zhg0FncfVF9-ReZOuck"
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}

# User ID from kr123 account
$userId = "1394378f-581f-4a69-9367-7d46b72649c3"

$body = @{
    "owner_id" = $userId
    "stream_url" = "https://resigned-shimmer-subtotal.ngrok-free.dev/video_feed"
    "is_activated" = $true
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "https://cnbrwbibvlbzzztenfzr.supabase.co/rest/v1/device_registrations?device_code=eq.LAPTOP001" -Headers $headers -Method PATCH -Body $body
    Write-Host "Success! LAPTOP001 is now linked to your account."
    $response | ConvertTo-Json -Depth 3
} catch {
    Write-Host "Error: $($_.Exception.Message)"
    $stream = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $responseBody = $reader.ReadToEnd()
    Write-Host "Response: $responseBody"
}