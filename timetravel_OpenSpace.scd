s.boot;
s.quit;
Server.killAll; // om udp socket address används

// för 8 kanaler, reboota om det behövs
(
o = Server.default.options;
o.device = "ASIO : MOTU Gen 5";
s.options.numOutputBusChannels = 10;
Server.default.reboot;
)


s.scope;
s.freqscope;
Window.browse; // använd browse för att se alla argument osv som något har

//////////////////////////////////////////////
// KODEN

(
// skapa en array av buffrar och använd path för att fylla med låtar
var folder = PathName.new(thisProcess.nowExecutingPath.dirname ++ "/billboard1936/");
folder.postln;
Buffer.freeAll;

// globala variabler
~changeSong; // global funktion
~jump = 5; // hur många låtar/s innan man skippar
~media = Array.new;


// fyll media array med låtar
folder.entries.do({
	arg path;
	~media = ~media.addFirst(Buffer.read(s, path.fullPath));
});
)

(
~surroundBus = Bus.audio(s,8); // en ny ljudbuss för surround setup.
~soundGrp = Group.new; // två grupper: denna innehåller låtsyntar
~fxGrp = Group.after(~soundGrp); // denna innehåller synt med korrekt reroute i domen

// synth för låtar
SynthDef(\player, { arg bufnum, amp = 0, crossfade, pos = 0;
	// buffratescale för att få samma samplingsfrekvens på alla, skalar om dem
	// TODO: tar endast v kanal för mono till surround, fuckar med tidigare låtar...
	var sig = PlayBuf.ar(2, bufnum, BufRateScale.kr(bufnum), loop: 1);
	sig = sig * amp.lag(crossfade); // fading med lag

	// azimuth panorering 8 kanaler, H i kanal 1 därav +2/7. Vi skippar C högtalare än så länge
	// höger öra
	sig[1] = PanAz.ar(
		numChans: 7,
		in: sig[1],
		pos: (2/7 + pos).lag(crossfade),
        level: 1,
        width: 1,
        orientation: 0
    );

	// vänster öra, pos är (12/7 - pos) pga L är kanal 6.
	sig[0] = PanAz.ar(
		numChans: 7,
		in: sig[0],
		pos: (12/7 - pos).lag(crossfade),
        level: 1,
        width: 1,
        orientation: 0
    );
	// OBS! verkar vara lite sticky, behöver starta om och köra kod 2 ggr så funkar det
	Out.ar(~surroundBus, sig[0]); // left output
	Out.ar(~surroundBus, sig[1]); // right output
}).add;

// synth för reroute till domen
SynthDef.new(\reroute, {
	arg sigbus, lfemix=0.3;
	Out.ar(2, In.ar(sigbus, 1));   //C
	Out.ar(1, In.ar(sigbus+1, 1)); //R
	Out.ar(5, In.ar(sigbus+2, 1)); //RS
	Out.ar(7, In.ar(sigbus+3, 1)); //RB
	Out.ar(6, In.ar(sigbus+4, 1)); //LB
	Out.ar(4, In.ar(sigbus+5, 1)); //LS
	Out.ar(0, In.ar(sigbus+6, 1)); //L
	Out.ar(3, lfemix*(Mix(In.ar(sigbus, 7)))); //LFE
}).add;

// deklaration av 2 låtsyntar, byter aktiv synt när låt byts i changeSong
~synth0 = Synth.new(\player, [\bufnum, ~media[0]], ~soundGrp).register;
~synth1 = Synth.new(\player, [\bufnum, ~media[1]], ~soundGrp).register;
~activesynth = ~synth1; ~inactivesynth = ~synth0;
~activesynth.set(\amp, 1); // aktiv synt spelar i början

~reroute = Synth.new(\reroute, [\sigbus,~surroundBus], ~fxGrp);

// funktion som ändrar låt baserat på sliders värde
~changeSong = {
	arg media_index, crossfade, direction;
	//crossfade.postln;
	// Om låten har bytts, spela den i synten som inte används, muta den andra.
	if (~activesynth == ~synth0, {
		~activesynth = ~synth1; ~inactivesynth = ~synth0;
		~synth1.set(\bufnum, ~media[media_index]);
		//~synth0.set(\crossfade, crossfade);
		"synth1 playing".postln;
		~surround.value(crossfade, direction);
	}, {
		~activesynth = ~synth0; ~inactivesynth = ~synth1;
		~synth0.set(\bufnum, ~media[media_index]);
		//~synth1.set(\crossfade, crossfade);
		"synth0 playing".postln;
		~surround.value(crossfade, direction);
	};)

};
)
(
// funktion som ändrar vart kanalerna spelar för svepande surround vid låtbyte
~surround = {
	arg crossfade, direction;

	if( direction == 1,{
		{
			~activesynth.set(\pos, (8/7), \crossfade, 0, \amp, 1);
			~inactivesynth.set(\pos, 0, \crossfade, 0, \amp, 1);
			~activesynth.set(\pos, 0, \crossfade, crossfade);
			~inactivesynth.set(\amp, 0, \crossfade, crossfade);
			(crossfade).wait; ~inactivesynth.set(\pos, (8/7), \crossfade, 0, \amp, 0);
		}.forkIfNeeded;
		//
		("Back").postln;
    },{


		{
			~activesynth.set(\pos, 0, \crossfade, 0, \amp, 1);
			~inactivesynth.set(\pos, 0, \crossfade, 0, \amp, 1);
			~inactivesynth.set(\pos, (8/7), \crossfade, crossfade, \amp, 0);
			//(crossfade).wait; ~inactivesynth.set(\amp, 0, \crossfade, crossfade);
		}.forkIfNeeded;
		("Front").postln;
		direction.postln;
    });
	("Surround").postln;

}
)

(
var dist_prev = 0; // if distance is same after
var dist_rest = 0;
var skip_alt = 2;
var crossfade, dist_skip;  // hur lång crossfade tiden är (sekunder), dist_skip != dist_ly
var time_prev = Clock.seconds;
// Starta OSC och lyssna på meddelanden
OSCdef.new(\earth,
	{
		arg msg;
		var dist_ly = msg[1]/9.4607e+12; // distance from earth in lightyears
		var speed_ly_s = msg[2]/(9.4607e+12 / 2); // speed of camera in lightyears per second
		// med ljusår/2 fås hastighet i ljusår/s (ly/s), vet ej varför...
		var direction = msg[3];
		// max hastighet runt 30 ly/s, fade lika lång som hälften av låtlängden
		// detta borde göra att man höra varje låt, även då det går snabbt
		crossfade = 1/speed_ly_s.linlin(0, 40, 0.2, 80);

		("Distance (lightyears):" + dist_ly).postln;
		//("Speed (ly/s):" + speed_ly_s).postln;
		//("Crossfade time alt1 (s):" + crossfade).postln;
		//("Direction:" + direction).postln;
		// rundar av speed till 3 dec. påverkar speed.postln och crossfade!
		// speed_ly_s = (speed_ly_s * 1000).round / 1000;

		dist_ly = dist_ly.asInteger;
		if(dist_ly > 88) {dist_ly = 88;}; // finns bara 89 låtar i spellistan

		// algoritmen för att hoppa över låtar vid vissa hastigheter.
		dist_rest = (floor(speed_ly_s/~jump));
		dist_skip = dist_ly;
			if (direction == 1) {dist_skip = dist_ly + dist_rest;}; // från jorden -> lägg till rest

		if ( (abs(dist_prev - dist_skip) > dist_rest) && ( speed_ly_s >= ~jump) ) {
			crossfade = crossfade * (speed_ly_s / ~jump); // kompensera så crossfade mitt av låten ca
			~changeSong.value(dist_skip, crossfade, direction);
			dist_prev = dist_skip;
			("Crossfade time kompenserad(s):" + crossfade).postln;
			//("Dist_skip (lightyears):" + dist_skip).postln;
			("Switch (s):" + (Clock.seconds - time_prev)).postln; time_prev = Clock.seconds;
			//("speed (ly/s):" + speed_ly_s).postln;
		};

		// om hastighet < jump, byt för varje år
		// TODO: känns att den inte funkar ibland när man gör snabba byten bak->fram
		// kanske beror på instabilitet i hastigheten...
		if ( (abs(dist_prev - dist_ly) > 0) && (speed_ly_s < ~jump) ){
			~changeSong.value(dist_ly, crossfade, direction);
			dist_prev = dist_ly;
		};


	},'/Earth');
)

(
//var distance0 = 0;
OSCdef.new(\time,
	{
		arg msg;
		var focus = msg[1];

		// speed calc from discrete derivative: speed = (distance - distance0)/deltatime
		//var distance = msg[1];
		//var speed = abs(distance - distance0)/time;
		//distance0 = distance.value;
		//("fn1:" + distance).postln;
		//("fn:" + distance0).postln;
		//("speed:" + speed).postln;

		dist_rest = (floor(speed_ly_s/~jump));
		dist_skip = dist_ly + dist_rest;

		if ( (abs(dist_prev - dist_skip) > dist_rest) ) {
				~changeSong.value(dist_skip, crossfade);
				dist_prev = dist_skip;
				("Dist_skip (lightyears):" + dist_skip).postln;
				("Switch (s):" + (Clock.seconds - time_prev)).postln; time_prev = Clock.seconds;
				("speed (ly/s):" + speed_ly_s).postln;
		};

		("Focus:" + focus).postln;
		//("Angle:" + msg[2]).postln;

	},'/TimeTravel');
)

Bus
