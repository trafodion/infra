<?php
# Stream MP3 with http://flash-mp3-player.net/players/mini/ mini mp3 player
# 
# Requires :
#   player_mp3_mini.swf in the extensions/MiniMp3 directory
# 
 
$wgHooks['ParserFirstCallInit'][] = 'wfMp3';
$wgMediaHandlers['audio/mp3'] = 'MiniMp3Handler';
$wgFileExtensions[] = 'mp3';
 
$wgExtensionCredits['parserhook'][] = array(
        'name' => 'MiniMp3',
        'description' => 'Uses a very small flash player to stream your mp3 files',
        'author' => array( 'Sylvain Machefert', 'Sam J Watkins', 'Reddo' ),
        'version' => '0.2',
        'url' => 'http://www.mediawiki.org/wiki/Extension:MiniMp3'
);
 
function wfMp3( Parser &$parser ) {
        $parser->setHook('mp3', 'renderMp3');
        return true;
}
 
# The callback function for converting the input text to HTML output
function renderMp3( $input, $params ) {
        global $wgScriptPath;
        $output= '';
 
        //get params
        //if no color param given for specific element default to general color param
        //if no general color param given default to 000000
        $Color = isset( $params['color'] ) ? $params['color'] : '000000';
        if ( $Color == '') 
        {
                $Color = '000000';
        }
 
        $slidColor = isset( $params['slidcolor'] ) ? $params['slidcolor'] : $Color ;
        $loadColor = isset( $params['loadcolor'] ) ? $params['loadcolor'] : $Color ;
        $buttColor = isset( $params['buttoncolor'] ) ? $params['buttoncolor'] : $Color ;
 
        $bg = isset( $params['bg'] ) ? $params['bg'] : 'C0C0C0'; 
        if ( $bg == '')
        {
                $bg = 'C0C0C0';
        }
 
        //do background code
        $backgroundCode = Html::element( 'param', array( 'name' => "wmode", 'value' => "transparent" ) );
        if ($bg != ''){
                $backgroundCode = Html::element( 'param', array( 'name' => "bgcolor", 'value' => "#{$bg}" ) );
        }
 
        //File uploaded or external link ?
        $img = wfFindFile($input);
        if (!$img) { 
                $mp3 = $input;
        } 
        else { 
                $mp3 = $img->getFullURL();
        }
 
        unset($img);
 
        $flashFile = $wgScriptPath.'/extensions/MiniMp3/player_mp3_mini.swf';
 
        $output .= '<object type="application/x-shockwave-flash" data="'.$flashFile.'" width="200" height="20">'
        . Html::element( 'param', array( 'name' => "movie", 'value' => "{$flashFile}" ) )
        . $backgroundCode
        . Html::element( 'param', array( 'name' => "buttoncolor", 'value' => "#{$buttColor}" ) )
        . Html::element( 'param', array( 'name' => "slidercolor", 'value' => "#{$slidColor}" ) )
        . Html::element( 'param', array( 'name' => "FlashVars", 'value' => wfArrayToCGI( array( 'mp3' => $mp3, 'bgcolor' => $bg, 'loadingcolor' => $loadColor, 'buttoncolor' => $buttColor, 'slidercolor' => $slidColor ) ) ) )
        . '</object>';
 
        return $output;
}
 
class MiniMp3Handler extends MediaHandler {
 
        function validateParam( $name, $value ) { return true; }
        function makeParamString( $params ) { return ''; }
        function parseParamString( $string ) { return array(); }
        function normaliseParams( $file, &$params ) { return true; }
        function getImageSize( $file, $path ) { return false; }
 
        function getParamMap() {
                return array(
                        'mp3_color' => 'color',
                        'mp3_slidecolor' => 'slidcolor',
                        'mp3_loadcolor' => 'loadcolor',
                        'mp3_buttoncolor' => 'buttoncolor',
                        'mp3_backColor' => 'bg',
                );
        }
 
        # Prevent "no higher resolution" message.
        function mustRender( $file ) { return true; }
 
        function doTransform ( $file, $dstPath, $dstUrl, $params, $flags = 0 ) {
                return new Mp3Output( $this->getParamMap (), $file->getFullUrl () );
        }
}
 
class Mp3Output extends MediaTransformOutput {
var $buttColor, $slidColor, $loadColor, $bg, $mp3;
 
        function __construct( $params, $mp3 ){
                $Color = isset( $params['color'] ) ? $params['color'] : '50A6C2';
                if ( $Color == '') 
                {
                        $Color = '50A6C2';
                }
 
                $this->slidColor = isset( $params['mp3_slidecolor'] ) ? $params['mp3_slidecolor'] : $Color ;
                $this->loadColor = isset( $params['mp3_loadcolor'] ) ? $params['mp3_loadcolor'] : $Color ;
                $this->buttColor = isset( $params['mp3_buttoncolor'] ) ? $params['mp3_buttoncolor'] : $Color ;
                $this->bg = isset( $params['mp3_backColor'] ) ? $params['mp3_backColor'] : ''; 
 
                $this->mp3 = $mp3;
        }
 
        function toHtml( $options=array () ) {
                $backgroundCode = Html::element( 'param', array( 'name' => "wmode", 'value' => "transparent" ) );
                if ($bg != ''){
                        $backgroundCode = Html::element( 'param', array( 'name' => "bgcolor", 'value' => "#{$bg}" ) );
                }
 
                $flashFile = '/w/extensions/MiniMp3/player_mp3_mini.swf';
 
                $output .= '<object type="application/x-shockwave-flash" data="'.$flashFile.'" width="200" height="20">'
                . Html::element( 'param', array( 'name' => "movie", 'value' => "{$flashFile}" ) )
                . $backgroundCode
                . Html::element( 'param', array( 'name' => "buttoncolor", 'value' => "#{$this->buttColor}" ) )
                . Html::element( 'param', array( 'name' => "slidercolor", 'value' => "#{$this->slidColor}" ) )
                . Html::element( 'param', array( 'name' => "loadingcolor", 'value' => "#{$this->loadColor}" ) )
                . Html::element( 'param', array( 'name' => "FlashVars", 'value' => wfArrayToCGI( array( 'mp3' => $this->mp3, 'bgcolor' => $this->bg, 'loadingcolor' => $this->loadColor, 'buttoncolor' => $this->buttColor, 'slidercolor' => $this->slidColor ) ) ) )
                . '</object>';
 
                return $output;
        }
}

