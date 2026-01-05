import type { Meta, StoryObj } from "@storybook/react-vite";
import type { ReactNode } from "react";
import { Button } from "../components/form/Button";
import { FormActions } from "../components/form/FormActions";
import { Input } from "../components/form/Input";
import type { Form } from "../hooks/useForm";

interface Props {
  children?: ReactNode;
}

const FormComponent = ({ children }: Props) => (
  <form
    className="p-8 rounded-lg space-y-8 shadow-xl w-[40em]"
    onSubmit={(e) => e.preventDefault()}
  >
    {children}
  </form>
);

type FormFields = {
  name: string | null;
  password: string | null;
  choice: string | null;
};

const form: Form<FormFields> = {
  id: "testForm",
  isPending: false,
  action() {},
  state: {
    fields: {
      name: null,
      password: null,
      choice: null,
    },
    errors: {},
  },
};

const meta = {
  title: "Forms/Basic Form",
  component: FormComponent,
  tags: ["!autodocs", "!dev"],
} satisfies Meta<typeof FormComponent>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Basic: Story = {
  args: {
    children: [
      <Input<FormFields>
        key="display_name"
        form={form}
        label="Display Name"
        field="name"
        type="text"
      />,

      <Input<FormFields>
        key="password"
        form={form}
        label="Password"
        field="password"
        type="password"
        help="Your password should remain secret!"
      />,

      <Input<FormFields>
        key="animal_preference"
        form={form}
        label="Pick one"
        field="choice"
        type="select"
        options={{
          cats: "Cats",
          dogs: "Dogs",
          both: "Why not both?",
        }}
      />,

      <FormActions key="actions" className="gap-2">
        <Button type="submit">Save</Button>
        <Button type="button" link>
          Cancel
        </Button>
      </FormActions>,
    ],
  },
};
