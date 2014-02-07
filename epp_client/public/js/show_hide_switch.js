function Hide (el) {
	if (document.getElementById(el)) {
		document.getElementById(el).className='hide';
	}
	else {
		alert('Нет элемента ' + el);
	}
}

function Switch (el) {
	if (document.getElementById(el).className == 'hide') {
		document.getElementById(el).className='show';
	}
	else {
		document.getElementById(el).className='hide';
	}
}

function Show (el) {
	if (document.getElementById(el)) {
		document.getElementById(el).className='show';
	}
	else {
		alert('Нет элемента ' + el);
	}
}

function chkChar(obj) {
	obj.value = obj.value.toUpperCase();
	obj.value = obj.value.replace(/[^a-zA-Z0-9-]/gi, '');
}

function chkDigit(obj) {
	obj.value = obj.value.toUpperCase();
	obj.value = obj.value.replace(/[^0-9]/gi, '');
}

function checkChar(obj){
	obj.value = obj.value.replace(/[^a-z0-9-]/gi,'');
	obj.value = obj.value.replace(/^[-]/gi,'');
	if (obj.value.length > 0) {
		document.getElementById('sub').disabled = false;
	}
	else {
		document.getElementById('sub').disabled = true;
	}
}

function checkLogin(obj){
	obj.value = obj.value.replace(/[^a-z0-9]/gi,'');
	if (obj.value.length > 0) {
		document.getElementById('singup').disabled = false;
	}
	else {
		document.getElementById('singup').disabled = true;
	}
}

function CheckTranferFields() {
	var lst = new Array('authinfo','login','pass');
	var list = new Array('acceptdog','acceptown');
	CheckBox(lst, list);
}

function CheckTranferFieldsAuth() {
	var lst = new Array('authinfo');
	var list = new Array('acceptown','acceptdog');
	CheckBox(lst, list);
}

function CheckLoginFields() {
	var lst = new Array('login','pass');
	CheckFld(lst);
}

function CheckFields() {
	var lst = new Array('login','pass','cc','name','email','voice','pc','city','street');
	CheckFld(lst);
}

function CheckFieldsAdmin() {
	var lst = new Array('login','cc','name','email','voice','pc','city','street');
	CheckFld(lst);
}

function CheckBox(lst, list) {
	document.getElementById('singup').disabled = false;
	for (var i = 0; i < lst.length; i++) {
		var str = window.document.getElementById(lst[i]).value;
		if (str.length == 0) {
			document.getElementById('singup').disabled = true;
			document.getElementById(lst[i]).className = 'empty';
		}
		else {
			document.getElementById(lst[i]).className = 'wdth';
		}
	}
	for (var i = 0; i < list.length; i++) {
		if (document.getElementById(list[i]).checked == false) {
			document.getElementById('singup').disabled = true;
			document.getElementById('text' + list[i]).className = 'textempty';
		}
		else {
			document.getElementById('text' + list[i]).className = '';
		}
	}
}

function CheckFld(lst) {
	var fields = new Array();
	document.getElementById('singup').disabled = false;
	for (var i = 0; i < lst.length; i++) {
		var str = window.document.getElementById(lst[i]).value;
		if (str.length == 0) {
			document.getElementById('singup').disabled = true;
			document.getElementById(lst[i]).className = 'empty';
		}
		else {
			document.getElementById(lst[i]).className = 'wdth';
		}
		if (lst[i] != 'pass') {
			fields.push(lst[i]+ '|' + str) ;
		}
	}
	SetCookie('fields_storage', fields);
}

function open_frame (url) {
	window.document.getElementById('modalframe').innerHTML = "<iframe " + "src='" + url + "'  width='100%' height='100%' frameBorder='0' style='border: 0'></iframe>"
}

function DnsSwitch(menu) {
	if (menu == 'mnu1') {
		document.getElementById('mnu1').className = 'domain-menua';
		document.getElementById('mnu2').className = 'domain-menu';
		Hide('ns');
		Show('dns');
	}
	else {
		document.getElementById('mnu1').className = 'domain-menu';
		document.getElementById('mnu2').className = 'domain-menua';
		Hide('dns');
		Show('ns');
	}

	var fields = new Array();
	fields.push(menu) ;
	SetCookie('dns_storage', fields);
}