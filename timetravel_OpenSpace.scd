s.boot;
s.quit;
Server.killAll; // om udp socket address används

// för 8 kanaler, reboot behövs inte alltid
o = Server.default.options;
o.device = "ASIO : MOTU Gen 5";
s.options.numOutputBusChannels = 10;
Server.default.reboot;

s.scope;
s.freqscope;
Window.browse; // använd browse för att se alla argument osv som något har

//////////////////////////////////////////////
// KODEN


(
//var distance0 = 0;
// Starta OSC och lyssna på meddelanden
OSCdef.new(\earth,
	{
		arg msg;

		var distance_light = msg[1]/9.4607e+12;
		var speed = msg[2]/(9.4607e+12 / 2);
		// med ljusår/2 fås hastighet i ljusår/s (ly/s), vet ej varför...
		var direction = msg[3];

		// speed calc from discrete derivative: speed = (distance - distance0)/time
		//var distance = msg[1];
		//var speed = abs(distance - distance0)/time;
		//distance0 = distance.value;
		//("fn1:" + distance).postln;
		//("fn:" + distance0).postln;
		//("speed:" + speed).postln;


		("Distance in lightyears:" + distance_light).postln;
		speed = (speed * 1000).round / 1000; // rundar av till 3 dec. påverkar speed.postln och crossfade!
		("speed:" + speed).postln;
		//("direction:" + direction).postln;

		distance_light = distance_light.asInteger;
		if (distance_light < 89) {~songSelector.value(distance_light);};


		// max hastighet runt 30 ly/s, fade lika lång som hälften av låtlängden
		// detta borde göra att man höra varje låt, även då det går snabbt
		~crossfade = 1/speed.linlin(0, 40, 0.2, 80);
		("crossfade:" + ~crossfade).postln;
	},'/Earth');
)

(
OSCdef.new(\time,
	{
		arg msg;
		var focus = msg[1];

		("Focus:" + focus).postln;
		//("Angle:" + msg[2]).postln;

	},'/TimeTravel');
)


// skapa en array av buffrar och använd path för att fylla med låtar
(
var folder = PathName.new(thisProcess.nowExecutingPath.dirname ++ "/billboard1936/");
folder.postln;
Buffer.freeAll;

// globala variabler
~crossfade; // sätt 0 för hårdklipp, 5 för vanligt
~toggle = 1; // toggle visar vilken av syntarna som nuvarande vald låt spelas på
~currentSong = 0;
~synth0; ~synth1;
~songSelector;
~media = Array.new;

folder.entries.do({
	arg path;
	~media = ~media.addFirst(Buffer.read(s, path.fullPath));
});
)

(
SynthDef(\player, { arg out, bufnum, amp = 0, crossfade;
	// buffratescale för att få samma samplingsfrekvens på alla, skalar om dem
	var sig = PlayBuf.ar(2, bufnum, BufRateScale.kr(bufnum), loop: 1);
	sig = sig * amp.lag(crossfade); // fading med lag, minska laghastighet när låtar byter snabbare?
	Out.ar(out, sig); // TODO: arg out kan tas bort? byt ut den mot 0 bara
}).add;

// funktion som ändrar låt baserat på sliders värde

~synth0 = Synth.new(\player, [\bufnum, ~media[0]], s).register;
~synth1 = Synth.new(\player, [\bufnum, ~media[1]], s).register;
~synth1.set(\amp, 1); // synth 1 spelar i början, kommer köra tidigaste låten när SC startar

~songSelector = {
	arg slideVal = 0;
	//slideVal.postln;
	// Om låten har bytts, spela den i synten som inte används, muta den andra.
	if (slideVal != ~currentSong) {
		~currentSong = slideVal;
		if (~toggle == 0, {
			~toggle = 1; ~synth1.set(\bufnum, ~media[slideVal], \crossfade, ~crossfade);
			~synth1.set(\amp, 1);
			~synth0.set(\amp, 0); "synth1 playing".postln;
		}, {
			~toggle = 0; ~synth0.set(\bufnum, ~media[slideVal], \crossfade, ~crossfade);
			~synth0.set(\amp, 1);
			~synth1.set(\amp, 0); "synth0 playing".postln;
		};)
	};
};
)