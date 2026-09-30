// Leaves ran.marker behind, so a check can prove that report generation ran no verification.
require("node:fs").writeFileSync("ran.marker", "1");
