﻿package away3d.events {
    import flash.events.*;

    public class ShadingMethodEvent extends Event {

        public static const SHADER_INVALIDATED:String = "ShaderInvalidated";

        public function ShadingMethodEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false){
            super(type, bubbles, cancelable);
        }
    }
}//package away3d.events 
