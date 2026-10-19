class_name OnlineLogin
extends Node
## Main menu, joining: answers the server's login request (design logs
## 0115, 0116). A guest server gets this device's id. A Supabase server
## gets the saved session's token if there is one; otherwise, or if the
## server refused it, the menu shows "Log in with Google".

## The menu should show the login button.
signal needs_button
signal message(text: String)

var auth := SupabaseAuth.new()
## Who we're logged in as on a Supabase server, or "".
var email := ""
var _answers := 0


func _ready() -> void:
	auth.name = "Auth"
	add_child(auth)


## A new connection.
func reset() -> void:
	_answers = 0
	auth.cancel()


func answer(info: Dictionary) -> void:
	match info.get("auth"):
		"guest":
			Net.accounts.log_in_as_guest()
		"supabase":
			if str(info.get("key", "")) == "":
				message.emit("This server isn't set up for logins yet.")
				return
			auth.configure(str(info.get("url", "")), str(info.key))
			_answers += 1
			if _answers == 1:
				var token := await auth.access_token()
				if token != "":
					_send(token)
					return
			else:
				auth.forget()  # the server refused that login
				email = ""
			needs_button.emit()
		_:
			message.emit("This server asks for a login this game doesn't know.")


func log_in_with_google() -> void:
	message.emit("Finish logging in in your browser…")
	var result := await auth.log_in()
	if result.has("error"):
		message.emit(result.error)
		needs_button.emit()
		return
	_send(result.token)


func log_out() -> void:
	auth.forget()
	email = ""


## Web: after coming back from the login page. True if now logged in.
func finish_web_login() -> bool:
	var result := await auth.finish_web_login()
	if result.has("error"):
		message.emit(result.error)
	return result.has("token")


func _send(token: String) -> void:
	email = auth.saved_email()
	message.emit("Logging in as %s…" % email if email != "" else "Logging in…")
	Net.accounts.log_in_with_token(token)
