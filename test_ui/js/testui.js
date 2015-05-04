$( document ).ready(function() {
	$("#test_link").click(function() {

        Caman.Event.listen("renderFinished", function () {
            console.timeEnd("total render::");
        });

		console.log("Testing");
		Caman('#pergola', function () {
            console.time("total render::");
            console.time("start render::");
    		this.brightness(10);
    		this.contrast(30);
    		this.sepia(60);
    		this.saturation(-30);
    		this.render();
            console.timeEnd("start render::");
  		});

	});

    $("#print_button").click(function() {
        increase();
    });

    $( "#print_button" ).append( '<div id="text">0</strong>' );
})


var a = 0;
    function increase(){
        a++;
        $('#text').text(a);
}  