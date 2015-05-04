$( document ).ready(function() {

    var startTime = 0;
    var nextTime = 0;
    var a = 0;



    function difference(){
        if (startTime === 0) {
            startTime = new Date();
        }
        nextTime = new Date();
        return nextTime - startTime;
    }

    function increase(){
        a++;
        $('#text').text(a);
        $( "#results" ).append( '<div class="resultlist"><span class="testN">' + a + '</span><span class="testTime">' + difference() + '</span></div>' );
    }

	$("#test_link").click(function() {


        $( "#results" ).append( '<div class="resultlist"><span class="testN">Test start</span><span class="testTime">' + difference() + '</span></div>' );

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