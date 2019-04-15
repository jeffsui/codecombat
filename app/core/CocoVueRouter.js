import VueRouter from 'vue-router'

import SchoolAdminDashboard from 'app/views/school-administrator/SchoolAdministratorComponent'
import SchoolAdminDashboardTeacherListView from 'app/views/school-administrator/teachers/SchoolAdminTeacherListView'
import SchoolAdminTeacherView from 'app/views/school-administrator/dashboard/SchoolAdminDashboardTeacherView'

import TeacherClassView from 'views/teachers/class/TeacherClassView'
import TeacherStudentView from 'views/teachers/classes/TeacherStudentView'

Vue.use(VueRouter)

let vueRouter;

export default function () {
  if (typeof vueRouter === 'undefined') {
    vueRouter = new VueRouter({
      // Routing is currently driven by Backbone Router.  When we migrate away from backbone, switch to history
      mode: 'abstract',

      routes: [
        {
          path: '/school-administrator', component: SchoolAdminDashboard, children: [
            { path: '', component: SchoolAdminDashboardTeacherListView },
            { path: 'teacher/:teacherId', component: SchoolAdminTeacherView },
            { path: 'teacher/:teacherId/classroom/:classroomId', component: TeacherClassView },
            { path: 'teacher/:teacherId/classroom/:classroomId/:studentId', component: TeacherStudentView },
          ]
        }
      ]
    })
  }

  return vueRouter
}
