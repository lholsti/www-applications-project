$( document ).ready(function() {
	$("#test_link").click(function() {
		console.log("Testing");
		Caman('#pergola', function () {
    		this.brightness(10);
    		this.contrast(30);
    		this.sepia(60);
    		this.saturation(-30);
    		console.time("render");
    		this.render();
    		console.timeEnd("render");
  		});
	});
})