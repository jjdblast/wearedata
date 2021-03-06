﻿package aze.motion {
    import aze.motion.easing.*;
    import flash.utils.*;
    import flash.events.*;
    import flash.display.*;
    import aze.motion.specials.*;
    import flash.filters.*;
    import flash.geom.*;

    public final class EazeTween {

        public static const specialProperties:Dictionary = new Dictionary();
        private static const running:Dictionary = new Dictionary();
        private static const ticker:Shape = createTicker();

        public static var defaultEasing:Function = Quadratic.easeOut;
        public static var defaultDuration:Object = {
            slow:1,
            normal:0.4,
            fast:0.2
        };
        private static var pauseTime:Number;
        private static var head:EazeTween;
        private static var tweenCount:int = 0;

        private var prev:EazeTween;
        private var next:EazeTween;
        private var rnext:EazeTween;
        private var isDead:Boolean;
        private var target:Object;
        private var reversed:Boolean;
        private var overwrite:Boolean;
        private var autoStart:Boolean;
        private var _configured:Boolean;
        private var _started:Boolean;
        private var _inited:Boolean;
        private var duration;
        private var _duration:Number;
        private var _ease:Function;
        private var startTime:Number;
        private var endTime:Number;
        private var properties:EazeProperty;
        private var specials:EazeSpecial;
        private var autoVisible:Boolean;
        private var slowTween:Boolean;
        private var _chain:Array;
        private var _onStart:Function;
        private var _onStartArgs:Array;
        private var _onUpdate:Function;
        private var _onUpdateArgs:Array;
        private var _onComplete:Function;
        private var _onCompleteArgs:Array;

        public function EazeTween(target:Object, autoStart:Boolean=true){
            super();
            if (!(target)){
                throw (new ArgumentError("EazeTween: target can not be null"));
            };
            this.target = target;
            this.autoStart = autoStart;
            this._ease = defaultEasing;
        }
        public static function killAllTweens():void{
            var target:Object;
            for (target in running) {
                killTweensOf(target);
            };
        }
        public static function killTweensOf(target:Object):void{
            var rprev:EazeTween;
            if (!(target)){
                return;
            };
            var tween:EazeTween = running[target];
            while (tween) {
                tween.isDead = true;
                tween.dispose();
                if (tween.rnext){
                    rprev = tween;
                    tween = tween.rnext;
                    rprev.rnext = null;
                } else {
                    tween = null;
                };
            };
            delete running[target];
        }
        public static function pauseAllTweens():void{
            if (ticker.hasEventListener(Event.ENTER_FRAME)){
                pauseTime = getTimer();
                ticker.removeEventListener(Event.ENTER_FRAME, tick);
            };
        }
        public static function resumeAllTweens():void{
            var delta:Number;
            var tween:EazeTween;
            if (!(ticker.hasEventListener(Event.ENTER_FRAME))){
                delta = (getTimer() - pauseTime);
                tween = head;
                while (tween) {
                    tween.startTime = (tween.startTime + delta);
                    tween.endTime = (tween.endTime + delta);
                    tween = tween.next;
                };
                ticker.addEventListener(Event.ENTER_FRAME, tick);
            };
        }
        private static function createTicker():Shape{
            var sp:Shape = new Shape();
            sp.addEventListener(Event.ENTER_FRAME, tick);
            return (sp);
        }
        private static function tick(e:Event):void{
            if (head){
                updateTweens(getTimer());
            };
        }
        private static function updateTweens(time:int):void{
            var isComplete:Boolean;
            var k:Number;
            var ke:Number;
            var target:Object;
            var p:EazeProperty;
            var s:EazeSpecial;
            var dead:EazeTween;
            var prev:EazeTween;
            var cd:CompleteData;
            var i:int;
            var complete:Array = [];
            var ct:int;
            var t:EazeTween = head;
            var cpt:int;
            while (t) {
                cpt++;
                if (t.isDead){
                    isComplete = true;
                } else {
                    isComplete = (time >= t.endTime);
                    k = ((isComplete) ? 1 : ((time - t.startTime) / t._duration));
                    ke = t._ease(((k) || (0)));
                    target = t.target;
                    p = t.properties;
                    while (p) {
                        target[p.name] = (p.start + (p.delta * ke));
                        p = p.next;
                    };
                    if (t.slowTween){
                        if (t.autoVisible){
                            target.visible = (target.alpha > 0.001);
                        };
                        if (t.specials){
                            s = t.specials;
                            while (s) {
                                s.update(ke, isComplete);
                                s = s.next;
                            };
                        };
                        if (t._onStart != null){
                            t._onStart.apply(null, t._onStartArgs);
                            t._onStart = null;
                            t._onStartArgs = null;
                        };
                        if (t._onUpdate != null){
                            t._onUpdate.apply(null, t._onUpdateArgs);
                        };
                    };
                };
                if (isComplete){
                    if (t._started){
                        cd = new CompleteData(t._onComplete, t._onCompleteArgs, t._chain, (t.endTime - time));
                        t._chain = null;
                        complete.unshift(cd);
                        ct++;
                    };
                    t.isDead = true;
                    t.detach();
                    t.dispose();
                    dead = t;
                    prev = t.prev;
                    t = dead.next;
                    if (prev){
                        prev.next = t;
                        if (t){
                            t.prev = prev;
                        };
                    } else {
                        head = t;
                        if (t){
                            t.prev = null;
                        };
                    };
                    dead.prev = (dead.next = null);
                } else {
                    t = t.next;
                };
            };
            if (ct){
                i = 0;
                while (i < ct) {
                    complete[i].execute();
                    i++;
                };
            };
            tweenCount = cpt;
        }

        private function configure(duration, newState:Object=null, reversed:Boolean=false):void{
            var name:String;
            var value:*;
            this._configured = true;
            this.reversed = reversed;
            this.duration = duration;
            if (newState){
                for (name in newState) {
                    value = newState[name];
                    if ((name in specialProperties)){
                        if (name == "alpha"){
                            this.autoVisible = true;
                            this.slowTween = true;
                        } else {
                            if (name == "alphaVisible"){
                                name = "alpha";
                                this.autoVisible = false;
                            } else {
                                if (!((name in this.target))){
                                    if (name == "scale"){
                                        this.configure(duration, {
                                            scaleX:value,
                                            scaleY:value
                                        }, reversed);
                                        //unresolved jump
                                    };
                                    this.specials = new specialProperties[name](this.target, name, value, this.specials);
                                    this.slowTween = true;
                                    //unresolved jump
                                };
                            };
                        };
                    };
                    if ((((value is Array)) && ((this.target[name] is Number)))){
                        if (("__bezier" in specialProperties)){
                            this.specials = new specialProperties["__bezier"](this.target, name, value, this.specials);
                            this.slowTween = true;
                        };
                    } else {
                        this.properties = new EazeProperty(name, value, this.properties);
                    };
                };
            };
        }
        public function start(killTargetTweens:Boolean=true, timeOffset:Number=0):void{
            if (this._started){
                return;
            };
            if (!(this._inited)){
                this.init();
            };
            this.overwrite = killTargetTweens;
            this.startTime = (getTimer() + timeOffset);
            this._duration = (((isNaN(this.duration)) ? this.smartDuration(String(this.duration)) : Number(this.duration)) * 1000);
            this.endTime = (this.startTime + this._duration);
            if (((this.reversed) || ((this._duration == 0)))){
                this.update(this.startTime);
            };
            if (((this.autoVisible) && ((this._duration > 0)))){
                this.target.visible = true;
            };
            this._started = true;
            this.attach(this.overwrite);
        }
        private function init():void{
            if (this._inited){
                return;
            };
            var p:EazeProperty = this.properties;
            while (p) {
                p.init(this.target, this.reversed);
                p = p.next;
            };
            var s:EazeSpecial = this.specials;
            while (s) {
                s.init(this.reversed);
                s = s.next;
            };
            this._inited = true;
        }
        private function smartDuration(duration:String):Number{
            var s:EazeSpecial;
            if ((duration in defaultDuration)){
                return (defaultDuration[duration]);
            };
            if (duration == "auto"){
                s = this.specials;
                while (s) {
                    if (("getPreferredDuration" in s)){
                        return (s["getPreferredDuration"]());
                    };
                    s = s.next;
                };
            };
            return (defaultDuration.normal);
        }
        public function easing(f:Function):EazeTween{
            this._ease = ((f) || (defaultEasing));
            return (this);
        }
        public function filter(classRef, parameters:Object, removeWhenDone:Boolean=false):EazeTween{
            if (!(parameters)){
                parameters = {};
            };
            if (removeWhenDone){
                parameters.remove = true;
            };
            this.addSpecial(classRef, classRef, parameters);
            return (this);
        }
        public function tint(tint=null, colorize:Number=1, multiply:Number=NaN):EazeTween{
            if (isNaN(multiply)){
                multiply = (1 - colorize);
            };
            this.addSpecial("tint", "tint", [tint, colorize, multiply]);
            return (this);
        }
        public function colorMatrix(brightness:Number=0, contrast:Number=0, saturation:Number=0, hue:Number=0, tint:uint=0xFFFFFF, colorize:Number=0):EazeTween{
            var remove:Boolean = ((((((((!(brightness)) && (!(contrast)))) && (!(saturation)))) && (!(hue)))) && (!(colorize)));
            return (this.filter(ColorMatrixFilter, {
                brightness:brightness,
                contrast:contrast,
                saturation:saturation,
                hue:hue,
                tint:tint,
                colorize:colorize
            }, remove));
        }
        public function short(value:Number, name:String="rotation", useRadian:Boolean=false):EazeTween{
            this.addSpecial("__short", name, [value, useRadian]);
            return (this);
        }
        public function rect(value:Rectangle, name:String="scrollRect"):EazeTween{
            this.addSpecial("__rect", name, value);
            return (this);
        }
        private function addSpecial(special, name, value:Object):void{
            if ((((special in specialProperties)) && (this.target))){
                if (((((!(this._inited)) || ((this._duration == 0)))) && (this.autoStart))){
                    EazeSpecial(new specialProperties[special](this.target, name, value, null)).init(true);
                } else {
                    this.specials = new specialProperties[special](this.target, name, value, this.specials);
                    if (this._started){
                        this.specials.init(this.reversed);
                    };
                    this.slowTween = true;
                };
            };
        }
        public function onStart(handler:Function, ... _args):EazeTween{
            this._onStart = handler;
            this._onStartArgs = _args;
            this.slowTween = ((((((!(this.autoVisible)) || (!((this.specials == null))))) || (!((this._onUpdate == null))))) || (!((this._onStart == null))));
            return (this);
        }
        public function onUpdate(handler:Function, ... _args):EazeTween{
            this._onUpdate = handler;
            this._onUpdateArgs = _args;
            this.slowTween = ((((((!(this.autoVisible)) || (!((this.specials == null))))) || (!((this._onUpdate == null))))) || (!((this._onStart == null))));
            return (this);
        }
        public function onComplete(handler:Function, ... _args):EazeTween{
            this._onComplete = handler;
            this._onCompleteArgs = _args;
            return (this);
        }
        public function kill(setEndValues:Boolean=false):void{
            if (this.isDead){
                return;
            };
            if (setEndValues){
                this._onUpdate = (this._onComplete = null);
                this.update(this.endTime);
            } else {
                this.detach();
                this.dispose();
            };
            this.isDead = true;
        }
        public function killTweens():EazeTween{
            EazeTween.killTweensOf(this.target);
            return (this);
        }
        public function updateNow():EazeTween{
            var t:Number;
            if (this._started){
                t = Math.max(this.startTime, getTimer());
                this.update(t);
            } else {
                this.init();
                this.endTime = (this._duration = 1);
                this.update(0);
            };
            return (this);
        }
        private function update(time:Number):void{
            var h:EazeTween = head;
            head = this;
            updateTweens(time);
            head = h;
        }
        private function attach(overwrite:Boolean):void{
            var parallel:EazeTween;
            if (overwrite){
                killTweensOf(this.target);
            } else {
                parallel = running[this.target];
            };
            if (parallel){
                this.prev = parallel;
                this.next = parallel.next;
                if (this.next){
                    this.next.prev = this;
                };
                parallel.next = this;
                this.rnext = parallel;
            } else {
                if (head){
                    head.prev = this;
                };
                this.next = head;
                head = this;
            };
            running[this.target] = this;
        }
        private function detach():void{
            var targetTweens:EazeTween;
            var prev:EazeTween;
            if (((this.target) && (this._started))){
                targetTweens = running[this.target];
                if (targetTweens == this){
                    if (this.rnext){
                        running[this.target] = this.rnext;
                    } else {
                        delete running[this.target];
                    };
                } else {
                    if (targetTweens){
                        prev = targetTweens;
                        targetTweens = targetTweens.rnext;
                        while (targetTweens) {
                            if (targetTweens == this){
                                prev.rnext = this.rnext;
                                break;
                            };
                            prev = targetTweens;
                            targetTweens = targetTweens.rnext;
                        };
                    };
                };
                this.rnext = null;
            };
        }
        private function dispose():void{
            var tween:EazeTween;
            if (this._started){
                this.target = null;
                this._onComplete = null;
                this._onCompleteArgs = null;
                if (this._chain){
                    for each (tween in this._chain) {
                        tween.dispose();
                    };
                    this._chain = null;
                };
            };
            if (this.properties){
                this.properties.dispose();
                this.properties = null;
            };
            this._ease = null;
            this._onStart = null;
            this._onStartArgs = null;
            if (this.slowTween){
                if (this.specials){
                    this.specials.dispose();
                    this.specials = null;
                };
                this.autoVisible = false;
                this._onUpdate = null;
                this._onUpdateArgs = null;
            };
        }
        public function delay(duration, overwrite:Boolean=true):EazeTween{
            return (this.add(duration, null, overwrite));
        }
        public function apply(newState:Object=null, overwrite:Boolean=true):EazeTween{
            return (this.add(0, newState, overwrite));
        }
        public function play(frame=0, overwrite:Boolean=true):EazeTween{
            return (this.add("auto", {frame:frame}, overwrite).easing(Linear.easeNone));
        }
        public function to(duration, newState:Object=null, overwrite:Boolean=true):EazeTween{
            return (this.add(duration, newState, overwrite));
        }
        public function from(duration, fromState:Object=null, overwrite:Boolean=true):EazeTween{
            return (this.add(duration, fromState, overwrite, true));
        }
        private function add(duration, state:Object, overwrite:Boolean, reversed:Boolean=false):EazeTween{
            if (this.isDead){
                return (new EazeTween(this.target).add(duration, state, overwrite, reversed));
            };
            if (this._configured){
                return (this.chain().add(duration, state, overwrite, reversed));
            };
            this.configure(duration, state, reversed);
            if (this.autoStart){
                this.start(overwrite);
            };
            return (this);
        }
        public function chain(target:Object=null):EazeTween{
            var tween:EazeTween = new EazeTween(((target) || (this.target)), false);
            if (!(this._chain)){
                this._chain = [];
            };
            this._chain.push(tween);
            return (tween);
        }
        public function get isStarted():Boolean{
            return (this._started);
        }
        public function get isFinished():Boolean{
            return (this.isDead);
        }

        specialProperties.alpha = true;
        specialProperties.alphaVisible = true;
        specialProperties.scale = true;
    }
}//package aze.motion 

final class EazeProperty {

    public var name:String;
    public var start:Number;
    public var end:Number;
    public var delta:Number;
    public var next:EazeProperty;

    public function EazeProperty(name:String, end:Number, next:EazeProperty){
        super();
        this.name = name;
        this.end = end;
        this.next = next;
    }
    public function init(target:Object, reversed:Boolean):void{
        if (reversed){
            this.start = this.end;
            this.end = target[this.name];
            target[this.name] = this.start;
        } else {
            this.start = target[this.name];
        };
        this.delta = (this.end - this.start);
    }
    public function dispose():void{
        if (this.next){
            this.next.dispose();
        };
        this.next = null;
    }

}
final class CompleteData {

    private var callback:Function;
    private var args:Array;
    private var chain:Array;
    private var diff:Number;

    public function CompleteData(callback:Function, args:Array, chain:Array, diff:Number){
        super();
        this.callback = callback;
        this.args = args;
        this.chain = chain;
        this.diff = diff;
    }
    public function execute():void{
        var len:int;
        var i:int;
        if (this.callback != null){
            this.callback.apply(null, this.args);
            this.callback = null;
        };
        this.args = null;
        if (this.chain){
            len = this.chain.length;
            i = 0;
            while (i < len) {
                EazeTween(this.chain[i]).start(false, this.diff);
                i++;
            };
            this.chain = null;
        };
    }

}
