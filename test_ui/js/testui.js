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
        $( "#results" ).append( '<tr class="resultlist"><td class="testN">' + a + '</td><td class="testTime">' + difference() + '</td></tr>' );
    }

	$("#test_link").click(function() {


        $( "#results" ).append( '<tr class="resultlist"><td class="testN">Test start</td><td class="testTime">' + difference() + '</td></tr>' );

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