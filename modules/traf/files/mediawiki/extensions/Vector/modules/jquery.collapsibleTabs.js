/**
 * Collapsible tabs jQuery Plugin
 */
( function ( $ ) {
	var rtl = $( 'body' ).is( '.rtl' );
	$.fn.collapsibleTabs = function ( options ) {
		// return if the function is called on an empty jquery object
		if ( !this.length ) {
			return this;
		}
		// Merge options into the defaults
		var $settings = $.extend( {}, $.collapsibleTabs.defaults, options );

		this.each( function () {
			var $el = $( this );
			// add the element to our array of collapsible managers
			$.collapsibleTabs.instances = ( $.collapsibleTabs.instances.length === 0 ?
				$el : $.collapsibleTabs.instances.add( $el ) );
			// attach the settings to the elements
			$el.data( 'collapsibleTabsSettings', $settings );
			// attach data to our collapsible elements
			$el.children( $settings.collapsible ).each( function () {
				$.collapsibleTabs.addData( $( this ) );
			} );
		} );

		// if we haven't already bound our resize hanlder, bind it now
		if ( !$.collapsibleTabs.boundEvent ) {
			$( window )
				.delayedBind( '500', 'resize', function ( ) {
					$.collapsibleTabs.handleResize();
				} );
		}
		// call our resize handler to setup the page
		$.collapsibleTabs.handleResize();
		return this;
	};
	/**
	 * Returns the amount of horizontal distance between the two tabs groups
	 * (#left-navigation and #right-navigation), in pixels. If negative, this
	 * means that the tabs overlap, and the value is the width of overlapping
	 * parts.
	 *
	 * Used in default expandCondition and collapseCondition.
	 *
	 * @return {Numeric} distance/overlap in pixels
	 */
	function calculateTabDistance() {
		var $tabsArray, $leftTab, $rightTab, leftEnd, rightStart;

		// In RTL, #right-navigation is actually on the left and vice versa.
		// Hooray for descriptive naming.
		if ( !rtl ) {
			$leftTab = $( '#left-navigation' );
			$rightTab = $( '#right-navigation' );
		} else {
			$leftTab = $( '#right-navigation' );
			$rightTab = $( '#left-navigation' );
		}

		leftEnd = $leftTab.offset().left + $leftTab.width();
		rightStart = $rightTab.offset().left;

		return rightStart - leftEnd;
	}
	$.collapsibleTabs = {
		instances: [],
		boundEvent: null,
		defaults: {
			expandedContainer: '#p-views ul',
			collapsedContainer: '#p-cactions ul',
			collapsible: 'li.collapsible',
			shifting: false,
			expandCondition: function ( eleWidth ) {
				// If there's at least eleWidth pixels free space, expand.
				return calculateTabDistance() >= eleWidth;
			},
			collapseCondition: function () {
				// If there's an overlap, collapse.
				return calculateTabDistance() < 0;
			}
		},
		addData: function ( $collapsible ) {
			var $settings = $collapsible.parent().data( 'collapsibleTabsSettings' );
			if ( $settings !== null ) {
				$collapsible.data( 'collapsibleTabsSettings', {
					expandedContainer: $settings.expandedContainer,
					collapsedContainer: $settings.collapsedContainer,
					expandedWidth: $collapsible.width(),
					prevElement: $collapsible.prev()
				} );
			}
		},
		getSettings: function ( $collapsible ) {
			var $settings = $collapsible.data( 'collapsibleTabsSettings' );
			if ( $settings === undefined ) {
				$.collapsibleTabs.addData( $collapsible );
				$settings = $collapsible.data( 'collapsibleTabsSettings' );
			}
			return $settings;
		},
		/**
		 * @param {jQuery.Event} e
		 */
		handleResize: function () {
			$.collapsibleTabs.instances.each( function () {
				var $el = $( this ),
					data = $.collapsibleTabs.getSettings( $el );

				if ( data.shifting ) {
					return;
				}

				// if the two navigations are colliding
				if ( $el.children( data.collapsible ).length > 0 && data.collapseCondition() ) {

					$el.trigger( 'beforeTabCollapse' );
					// move the element to the dropdown menu
					$.collapsibleTabs.moveToCollapsed( $el.children( data.collapsible + ':last' ) );
				}

				// if there are still moveable items in the dropdown menu,
				// and there is sufficient space to place them in the tab container
				if ( $( data.collapsedContainer + ' ' + data.collapsible ).length > 0
						&& data.expandCondition( $.collapsibleTabs.getSettings( $( data.collapsedContainer ).children(
								data.collapsible + ':first' ) ).expandedWidth ) ) {
					//move the element from the dropdown to the tab
					$el.trigger( 'beforeTabExpand' );
					$.collapsibleTabs
						.moveToExpanded( data.collapsedContainer + ' ' + data.collapsible + ':first' );
				}
			});
		},
		moveToCollapsed: function ( ele ) {
			var $moving = $( ele );

			var data = $.collapsibleTabs.getSettings( $moving );
			if ( !data ) {
				return;
			}
			var expContainerSettings = $.collapsibleTabs.getSettings( $( data.expandedContainer ) );
			if ( !expContainerSettings ) {
				return;
			}
			expContainerSettings.shifting = true;

			// Remove the element from where it's at and put it in the dropdown menu
			var target = data.collapsedContainer;
			$moving.css( 'position', 'relative' )
				.css( ( rtl ? 'left' : 'right' ), 0 )
				.animate( { width: '1px' }, 'normal', function () {
					var data;
					$( this ).hide();
					// add the placeholder
					$( '<span class="placeholder" style="display: none;"></span>' ).insertAfter( this );
					// XXX: 'data' is undefined here, should the 'data' from the outer scope have
					// a different name?
					$( this ).detach().prependTo( target ).data( 'collapsibleTabsSettings', data );
					$( this ).attr( 'style', 'display: list-item;' );
					data = $.collapsibleTabs.getSettings( $( ele ) );
					if ( data ) {
						var expContainerSettings = $.collapsibleTabs.getSettings( $( data.expandedContainer ) );
						if ( expContainerSettings ) {
							expContainerSettings.shifting = false;
							$.collapsibleTabs.handleResize();
						}
					}
				} );
		},
		moveToExpanded: function ( ele ) {
			var $moving = $( ele );
			var data = $.collapsibleTabs.getSettings( $moving );
			if ( !data ) {
				return;
			}
			var expContainerSettings = $.collapsibleTabs.getSettings( $( data.expandedContainer ) );
			if ( !expContainerSettings ) {
				return;
			}
			expContainerSettings.shifting = true;

			// grab the next appearing placeholder so we can use it for replacing
			var $target = $( data.expandedContainer ).find( 'span.placeholder:first' );
			var expandedWidth = data.expandedWidth;
			$moving.css( 'position', 'relative' ).css( ( rtl ? 'right' : 'left' ), 0 ).css( 'width', '1px' );
			$target.replaceWith(
				$moving
				.detach()
				.css( 'width', '1px' )
				.data( 'collapsibleTabsSettings', data )
				.animate( { width: expandedWidth + 'px' }, 'normal', function () {
					$( this ).attr( 'style', 'display: block;' );
					var data = $.collapsibleTabs.getSettings( $( this ) );
					if ( data ) {
						var expContainerSettings = $.collapsibleTabs.getSettings( $( data.expandedContainer ) );
						if ( expContainerSettings ) {
							expContainerSettings.shifting = false;
							$.collapsibleTabs.handleResize();
						}
					}
				} )
			);
		}
	};

}( jQuery ) );
