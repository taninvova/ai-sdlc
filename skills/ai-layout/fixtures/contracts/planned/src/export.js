module.exports = (rows) => rows.map((row) => row.join(",")).join("\n");
