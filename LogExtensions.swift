import Foundation

infix operator ~> : MultiplicationPrecedence
infix operator ~>> : MultiplicationPrecedence
infix operator ~!> : MultiplicationPrecedence
infix operator ~?> : MultiplicationPrecedence
infix operator ~V> : MultiplicationPrecedence
infix operator ~C> : MultiplicationPrecedence

func ~> (lhs: LogMan.Type, rhs: String) {
    lhs.log.debug(rhs)
}

func ~>> (lhs: LogMan.Type, rhs: String) {
    lhs.log.info(rhs)
}

func ~!> (lhs: LogMan.Type, rhs: String) {
    lhs.log.warning(rhs)
}

func ~?> (lhs: LogMan.Type, rhs: String) {
    lhs.log.error(rhs)
}

func ~V> (lhs: LogMan.Type, rhs: String) {
    lhs.log.verbose(rhs)
}

func ~C> (lhs: LogMan.Type, rhs: String) {
    lhs.log.critical(rhs)
}
