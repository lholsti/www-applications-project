$( document ).ready(function() {
	$("#test_link").click(function() {

        Caman.Event.listen("renderFinished", function () {
            console.log("done");
            console.timeEnd("total render");
        });

		console.log("Testing");
		Caman('#pergola', function () {
    		this.brightness(10);
    		this.contrast(30);
    		this.sepia(60);
    		this.saturation(-30);
    		console.time("total render");
            console.time("partial render");
    		this.render();
            console.timeEnd("partial render");
  		});

	});
    $("#print_button").click(function() {
        console.log('UI is responding'+ new Date());
    });
})