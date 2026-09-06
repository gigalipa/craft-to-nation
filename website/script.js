const comparison = document.querySelector(".perspective-comparison");
const control = document.querySelector("#perspective-control");

const updateComparison = () => comparison.style.setProperty("--position", `${control.value}%`);

control.addEventListener("input", updateComparison);
updateComparison();
