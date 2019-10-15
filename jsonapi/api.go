package jsonapi

import (
	"database/sql"
	"io"

	"github.com/gorilla/mux"
	"github.com/korylprince/httputil/auth"
	"github.com/korylprince/httputil/session"
)

//APIRouter is an API Router
type APIRouter struct {
	mux          *mux.Router
	output       io.Writer
	auth         auth.Auth
	sessionStore session.Store
	hook         AuthHookFunc
}

//Handle registers a ReturnHandlerFunc with the given parameters
func (r *APIRouter) Handle(method, path, action string, handler ReturnHandlerFunc, auth bool) {
	if auth {
		handler = withAuth(r.sessionStore, r.hook, handler)
	}

	r.mux.Methods(method).Path(path).Handler(
		withLogging(action, r.output,
			withJSONResponse(
				handler)))

}

//HandleTX registers a TXReturnHandlerFunc with the given parameters
func (r *APIRouter) HandleTX(method, path, action string, db *sql.DB, handler TXReturnHandlerFunc, auth bool) {
	r.Handle(method, path, action, WithTX(db, handler), auth)
}

//New returns a new APIRouter
func New(output io.Writer, auth auth.Auth, store session.Store, hook AuthHookFunc) *APIRouter {
	r := &APIRouter{
		mux:          mux.NewRouter(),
		output:       output,
		auth:         auth,
		sessionStore: store,
		hook:         hook,
	}
	r.mux.NotFoundHandler = NotFoundJSONHandler
	r.Handle("POST", "/auth", "Authenticate", r.authenticate, false)
	return r
}
