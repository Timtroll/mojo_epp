function placeholder_focus(buzz) {
	buzz.value = (buzz.value == 'введите что-нибудь') ? '' : buzz.value;
}

function placeholder_blur(buzz) {
	buzz.value = (buzz.value == '') ? 'введите что-нибудь' : buzz.value
}

function Loadiframe (elem, cnt, nam) {
	var el = nam + cnt;
	if (elem.contentWindow.document.getElementById('d'+el)) {
		var cont = (new XMLSerializer()).serializeToString(elem.contentWindow.document.getElementById('d'+el));
		window.document.getElementById(el).className = '';
		window.document.getElementById(el).innerHTML = cont;
	}
}
