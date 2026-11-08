const http = require("http");
const os = require("os");

const PORT = 3000;
const VERSION = process.env.APP_VERSION || "1.0.0";
const POD_NAME = process.env.HOSTNAME || os.hostname();

const server = http.createServer((req, res) => {
  if (req.url === "/healthz") {
    res.writeHead(200, { "Content-Type": "text/plain" });
    return res.end("OK");
  }

  if (req.url === "/") {
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    return res.end(`
      <!DOCTYPE html>
      <html>
        <head><title>DevOps Exercise</title></head>
        <body>
          <h1>Hello from EX.CO version 2!</h1>
          <p>App version: ${VERSION}</p>
          <p>Pod name: ${POD_NAME}</p>
        </body>
      </html>
    `);
  }

  res.writeHead(404);
  res.end("Not found");
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Server listening on port ${PORT}`);
});
