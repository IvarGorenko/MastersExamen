s.boot;
s.quit;
Server.killAll; // om udp socket address används

// för 8 kanaler, reboota om det behövs
(
o = Server.default.options;
o.device = "ASIO : MOTU Gen 5";
s.options.numOutputBusChannels = 10;
)
Server.default.reboot;

s.scope;
s.freqscope;
Window.browse; // använd browse för att se alla argument osv som något har

//////////////////////////////////////////////
// KODEN

// skapa en array av buffrar och använd path för att fylla med låtar
(
var folder = PathName.new(thisProcess.nowExecutingPath.dirname ++ "/billboard1936/");
folder.postln;
Buffer.freeAll;

// globala variabler
~changeSong;
~jump = 0.1; // hur många låtar/s innan man skippar
~media = Array.new;

folder.entries.do({
	arg path;
	~media = ~media.addFirst(Buffer.read(s, path.fullPath));
});
)

(
SynthDef(\player, { arg out, bufnum, amp = 0, crossfade, pos = 0;
	// buffratescale för att få samma samplingsfrekvens på alla, skalar om dem
	var sig = PlayBuf.ar(1, bufnum, BufRateScale.kr(bufnum), loop: 1);
	sig = sig * amp.lag(crossfade); // fading med lag
	sig = PanAz.ar(
		numChans: 8,
        in: sig,
        pos: pos,
        level: 1,
        width: 2,
        orientation: 0.5
    ); // OBS! verkar vara lite sticky, behöver starta om och köra kod 2 ggr så funkar det
	// out = [0,1,2,3,4,5,6,7];
	Out.ar(out, sig); // TODO: arg out kan tas bort? byt ut den mot 0 bara
}).add;

// deklaration av 2 syntar, byter aktiv synt när låt byts i changeSong
~synth0 = Synth.new(\player, [\bufnum, ~media[0]], s).register;
~synth1 = Synth.new(\player, [\bufnum, ~media[1]], s).register;
~activesynth = 1; // toggle för aktiv syntY
~synth1.set(\amp, 1); // synth 1 spelar i början

// funktion som ändrar låt baserat på sliders värde
~changeSong = {
	arg media_index, crossfade;
	//crossfade.postln;
	// Om låten har bytts, spela den i synten som inte används, muta den andra.
	if (~activesynth == 0, {
		~activesynth = 1; ~synth1.set(\bufnum, ~media[media_index], \crossfade, crossfade, \pos, 0);
		~synth1.set(\amp, 1);
		~synth0.set(\amp, 0); "synth1 playing".postln;
		~surround.value(~crossfade);
	}, {
		~activesynth = 0; ~synth0.set(\bufnum, ~media[media_index], \crossfade, crossfade);
		~synth0.set(\amp, 1);
		~synth1.set(\amp, 0); "synth0 playing".postln;
		~surround.value(~crossfade);
	};)

};
)
~media[8].query;

(
~surround = {
	arg crossfade;
	{~synth1.set(\pos, 1); 0.12.wait; ~synth1.set(\pos, 1.5)}.forkIfNeeded;
	("Hello").postln;

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

		//("Distance (lightyears):" + dist_ly).postln;
		//("Speed (ly/s):" + speed_ly_s).postln;
		//("Crossfade time alt1 (s):" + crossfade).postln;
		//("Direction:" + direction).postln;
		// rundar av speed till 3 dec. påverkar speed.postln och crossfade!
		// speed_ly_s = (speed_ly_s * 1000).round / 1000;

		dist_ly = dist_ly.asInteger;
		if(dist_ly > 88) {dist_ly = 88;}; // finns bara 89 låtar i spellistan


		// TODO: crossfade ändringen vid alt 2 funkar men inte superbra...
		// TODO: När vi går från gränsen till första låt byts det inte från brus, skippet börjar med brus
		// 3 alternativ för att skippa vid olika hastigheter
		// alt 1: skippa inte, gör bara låtbytet när vi får en ny låt
		// alt 2: vid ~jump hastighet ökar låthopp med 1, vid 2ggr hastighet blir hoppet 2 osv
		// alt 3: låtbyte har en bestämd minimal tid vid alla hastigheter (alt 2 med jump 1 i princip)
		switch (skip_alt,
		1, {
			if ( abs(dist_prev - dist_ly) > 0 ) {
				~changeSong.value(dist_ly, crossfade);
					dist_prev = dist_ly;
			};
		},
			2, { // Rätt bra men tidsdelta lite varierande (max 0.1 s), kolla anteckningar
			dist_rest = (floor(speed_ly_s/~jump));
			dist_skip = dist_ly;
			if (direction == 1) {dist_skip = dist_ly + dist_rest;}; // från jorden -> lägg till rest

			if ( (abs(dist_prev - dist_skip) > dist_rest) && ( speed_ly_s >= ~jump) ) {
				crossfade = crossfade * (speed_ly_s / ~jump); // kompensera så crossfade mitt av låten ca
				~changeSong.value(dist_skip, crossfade);
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
				~changeSong.value(dist_ly, crossfade);
				dist_prev = dist_ly;
			};
		},
		3, {


		};)

	},'/Earth');
)
floor((11.97/2))

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

(
{
    PanAz.ar(
        numChans: 8,
        in: ClipNoise.ar(0.1),
        pos: LFSaw.kr(MouseX.kr(0.2, 8, 'exponential')),
        level: 0.5,
        width: 4,
        orientation: 0.5
    );
}.play
)

(
// the arg direct will control the proportion of direct to processed signal
SynthDef("tutorial-DecayPink", { arg outBus = 0, effectBus, direct = 0.5;
    var source;
	outBus = [0,1,2,4,5,6,7];
    // Decaying pulses of PinkNoise. We'll add reverb later.
    source = Decay2.ar(Impulse.ar(1, 0.25), 0.01, 0.2, PinkNoise.ar);
    // this will be our main output
    Out.ar(outBus, source * direct);
    // this will be our effects output
	Out.ar(outBus, source * (1 - direct));
}).play;
)

(
{
    PanAz.ar(
		numChans: 8,
        in: ClipNoise.ar(0.1),
        pos: 1.5,
        level: 0.5,
        width: 2,
        orientation: 0.5
    );
}.play; // ändra bara pos från 0->1->1.5 för att få fram->mitt->bak
)