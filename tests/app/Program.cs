using System.Globalization;

var app = WebApplication.Create(args);

app.MapGet("/", () => ".NET test app");
// Fails in globalization-invariant mode, which the image turns off.
app.MapGet("/culture", () => new CultureInfo("de-DE").NumberFormat.NumberDecimalSeparator);
app.MapGet("/version", () => Environment.Version.ToString());

app.Run();
