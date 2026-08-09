({
    setBaseColor : function(component){
        // Get URL parameter
        const urlParams = new URLSearchParams(window.location.search);
        const colorValue = urlParams.get('color'); // assuming ?color=blue

        // Set CSS variable on :root
        if (colorValue) {
          document.documentElement.style.setProperty('--base-color', colorValue);
        }
    }
});