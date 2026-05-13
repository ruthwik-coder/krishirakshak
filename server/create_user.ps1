$body = @{
    "email" = "krishiuser2024@gmail.com"
    "password" = "krishi123"
} | ConvertTo-Json

$headers = @{
    "apikey" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuYnJ3Ymlidmxienp6dGVuZnpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjYzNjY0NCwiZXhwIjoyMDg4MjEyNjQ0fQ.YOwlm4NOakmQxChSHQ2D-364zhg0FncfVF9-ReZOuck"
    "Content-Type" = "application/json"
}

for ($i = 0; $i -lt 3; $i++) {
    try {
        Start-Sleep -Seconds 5
        $response = Invoke-RestMethod -Uri "https://cnbrwbibvlbzzztenfzr.supabase.co/auth/v1/signup" -Headers $headers -Method Post -Body $body
        Write-Host "Success: $($response | ConvertTo-Json -Depth 5)"
        break
    } catch {
        Write-Host "Attempt $($i+1) failed: $($_.Exception.Message)"
        if ($i -eq 2) {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $responseBody = $reader.ReadToEnd()
            Write-Host "Final Response: $responseBody"
        }
    }
}