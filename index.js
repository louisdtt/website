const express = require('express');
const path = require('path');

const app = express();
const port = 3000; 

// Render index.html on /
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, "index.html"));
});

// Access resources in the public folder
app.use(express.static(path.join(__dirname, "public")));

// Redirect everything to /
app.get('*', (req, res) => {
  res.redirect('/');
});

// Open app on port 3000
app.listen(port);
